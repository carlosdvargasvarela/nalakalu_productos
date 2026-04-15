class PurchaseOrderPdf
  include Prawn::View

  BRAND_COLOR = "1a56db"
  MUTED_COLOR = "6b7280"
  DARK_COLOR = "111827"
  BORDER_COLOR = "e5e7eb"
  HEADER_BG = "f9fafb"

  FONTS_PATH = Rails.root.join("app/assets/fonts")

  def initialize(purchase_order, items)
    @po = purchase_order
    @items = items

    Prawn::Fonts::AFM.hide_m17n_warning = true

    @document = Prawn::Document.new(
      page_size: "LETTER",
      page_layout: :portrait,
      margin: [36, 48, 48, 48]
    )

    # Registrar DejaVu con soporte UTF-8 completo
    @document.font_families.update(
      "DejaVu" => {
        normal: FONTS_PATH.join("DejaVuSans.ttf").to_s,
        bold: FONTS_PATH.join("DejaVuSans-Bold.ttf").to_s
      }
    )
    @document.font "DejaVu"

    build
  end

  def build
    header
    divider
    parties
    divider
    items_table
    totals_row
    notes_section if @po.notes.present?
    footer
  end

  # ── HEADER ──────────────────────────────────────────────────────────────
  def header
    bounding_box([0, cursor], width: bounds.width, height: 70) do
      # Izquierda — marca
      bounding_box([0, cursor], width: 280) do
        text "NALAKALÚ", size: 22, style: :bold, color: DARK_COLOR
        move_down 4
        text "Nalakalú Solutions S.A.", size: 8, color: MUTED_COLOR
        text "Ced. Jurídica: 3-101-477431", size: 8, color: MUTED_COLOR
        text "800m este de Concrepal, Palmares, Alajuela", size: 8, color: MUTED_COLOR
        text "Tel. +(506) 2453-8003", size: 8, color: MUTED_COLOR
      end

      # Derecha — número de OC
      bounding_box([bounds.width - 220, cursor + 70], width: 220) do
        text "ORDEN DE COMPRA", size: 8, style: :bold,
          color: MUTED_COLOR, align: :right
        text "##{@po.number}", size: 20, style: :bold,
          color: BRAND_COLOR, align: :right
        move_down 4
        text "Emitida: #{@po.issued_date&.strftime("%d/%m/%Y") || "—"}",
          size: 8, color: MUTED_COLOR, align: :right
        if @po.delivery_deadline.present?
          text "Entrega máx.: #{@po.delivery_deadline.strftime("%d/%m/%Y")}",
            size: 8, color: MUTED_COLOR, align: :right
        end
        move_down 4
        status_pill
      end
    end
    move_down 16
  end

  def status_pill
    label = @po.status.capitalize
    color = case @po.status
    when "borrador" then "6b7280"
    when "enviado" then "0ea5e9"
    when "confirmado" then "3b82f6"
    when "recibido" then "22c55e"
    when "cancelado" then "ef4444"
    else "6b7280"
    end
    text label, size: 9, style: :bold, color: color, align: :right
  end

  # ── PARTIES ─────────────────────────────────────────────────────────────
  def parties
    move_down 8
    col_width = (bounds.width - 16) / 2

    bounding_box([0, cursor], width: bounds.width) do
      # Proveedor
      bounding_box([0, cursor], width: col_width) do
        label "PROVEEDOR"
        text @po.provider.name, size: 10, style: :bold, color: DARK_COLOR
        text @po.provider.email, size: 8, color: MUTED_COLOR if @po.provider.email.present?
        text @po.provider.phone, size: 8, color: MUTED_COLOR if @po.provider.respond_to?(:phone) && @po.provider.phone.present?
      end

      # Destino
      bounding_box([col_width + 16, cursor + 46], width: col_width) do
        label "ENVIAR A"
        text "Nalakalú Solutions S.A.", size: 10, style: :bold, color: DARK_COLOR
        text "800m este de Concrepal, Palmares", size: 8, color: MUTED_COLOR
        text "Ced. Jurídica: 3-101-477431", size: 8, color: MUTED_COLOR
      end
    end
    move_down 16
  end

  # ── ITEMS TABLE ─────────────────────────────────────────────────────────
  def items_table
    move_down 8

    header_row = [
      [
        styled_cell("CÓDIGO", header: true, align: :left),
        styled_cell("DESCRIPCIÓN", header: true, align: :left),
        styled_cell("CANT.", header: true, align: :center),
        styled_cell("U/M", header: true, align: :center),
        styled_cell("PRECIO UNIT.", header: true, align: :right),
        styled_cell("TOTAL", header: true, align: :right)
      ]
    ]

    data_rows = @items.map do |item|
      desc = item.description_override.presence || item.supplier_item&.name.to_s
      specs = item.specifications.present? ?
        "\n#{item.specifications.map { |k, v| "#{k}: #{v}" }.join("  ·  ")}" : ""

      [
        make_cell(item.supplier_item&.sku || "—",
          size: 7, text_color: MUTED_COLOR, font_style: :normal),
        make_cell("#{desc}#{specs}",
          size: 9, text_color: DARK_COLOR),
        make_cell(item.quantity.to_f.round(2).to_s,
          size: 9, align: :center, font_style: :bold),
        make_cell(item.unit.to_s,
          size: 8, align: :center, text_color: MUTED_COLOR),
        make_cell(format_currency(item.unit_cost),
          size: 9, align: :right, text_color: MUTED_COLOR),
        make_cell(format_currency(item.total),
          size: 9, align: :right, font_style: :bold)
      ]
    end

    table(header_row + data_rows,
      width: bounds.width,
      cell_style: {borders: [:bottom], border_color: BORDER_COLOR,
                   padding: [8, 6, 8, 6]},
      column_widths: column_widths) do
      # Header styling
      row(0).background_color = HEADER_BG
      row(0).font_style = :bold
    end
  end

  def column_widths
    w = bounds.width
    [w * 0.10, w * 0.40, w * 0.09, w * 0.08, w * 0.16, w * 0.17]
  end

  # ── TOTALS ───────────────────────────────────────────────────────────────
  def totals_row
    move_down 4
    bounding_box([bounds.width - 200, cursor], width: 200) do
      text "Total Estimado", size: 8, color: MUTED_COLOR,
        align: :right, style: :bold
      move_down 2
      text format_currency(@po.total_amount), size: 14,
        style: :bold, color: DARK_COLOR, align: :right
    end
    move_down 32
  end

  # ── NOTES ────────────────────────────────────────────────────────────────
  def notes_section
    divider
    move_down 8
    label "NOTAS E INSTRUCCIONES"
    text @po.notes, size: 9, color: DARK_COLOR
    move_down 12
  end

  # ── FOOTER ───────────────────────────────────────────────────────────────
  def footer
    repeat(:all) do
      bounding_box([0, bounds.absolute_bottom + 24], width: bounds.width) do
        stroke_color BORDER_COLOR
        stroke_horizontal_rule
        move_down 6
        text "Nalakalú Solutions S.A.  ·  Ced. Jurídica: 3-101-477431  ·  Tel. +(506) 2453-8003",
          size: 7, color: MUTED_COLOR, align: :center
      end
    end
  end

  # ── HELPERS ──────────────────────────────────────────────────────────────
  def divider
    stroke_color BORDER_COLOR
    stroke_horizontal_rule
    move_down 12
  end

  def label(text_str)
    text text_str, size: 7, style: :bold, color: MUTED_COLOR
    move_down 3
  end

  def styled_cell(content, header: false, align: :left)
    make_cell(content,
      size: 8,
      font_style: :bold,
      text_color: MUTED_COLOR,
      align: align,
      background_color: HEADER_BG)
  end

  def format_currency(amount)
    return "₡0,00" if amount.nil?
    formatted = format("%.2f", amount.to_f)
      .reverse
      .gsub(/(\d{3})(?=\d)/, '\\1.')
      .reverse
      .sub(".", ",")
      .sub(/,(\d{2})$/, ',\1')
    # Reconstruir con separador correcto
    parts = format("%.2f", amount.to_f).split(".")
    integer_part = parts[0].reverse.gsub(/(\d{3})(?=\d)/, '\\1.').reverse
    "\u20A1#{integer_part},#{parts[1]}"
  end
end
