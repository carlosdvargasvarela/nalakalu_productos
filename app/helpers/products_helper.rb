module ProductsHelper
  SUPPLIER_TYPE_ICONS = {
    "interno" => "bi-house-check",
    "externo" => "bi-truck",
    "mixto" => "bi-arrow-left-right",
    "sin_definir" => "bi-question-circle"
  }.freeze

  def supplier_type_badge(product)
    s_type = product.supplier_type
    color = product.supplier_type_color
    icon = SUPPLIER_TYPE_ICONS[s_type]

    content_tag(:span, class: "badge bg-#{color}-soft text-#{color} rounded-pill px-3 border border-#{color} border-opacity-25") do
      content_tag(:i, "", class: "bi #{icon} me-1") + s_type.capitalize
    end
  end

  def supplier_type_info_icon(product)
    return unless product.supplier_type == "mixto"

    content_tag(:span, class: "text-muted small", style: "font-size: 0.7rem;") do
      content_tag(:i, "", class: "bi bi-info-circle",
        title: "Contiene variantes de proveedores internos y externos")
    end
  end
end
