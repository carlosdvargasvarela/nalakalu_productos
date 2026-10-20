module ApplicationHelper
  # Campo que se guarda solo al salir de él. kind: product, variant, supplier_item, provider, family, variant_type
  def quick_field(kind, record, field, type: "text", placeholder: nil, step: nil, css: "")
    tag.input(type: type, value: record[field], placeholder: placeholder, step: step, class: "form-control form-control-sm quick-field #{css}",
      data: {controller: "quick-edit", quick_edit_url_value: quick_edit_path(kind, record), quick_edit_field_value: field, action: "change->quick-edit#save"})
  end

  # Nombre editable + enlace para abrir el detalle
  def quick_name(kind, record, path, field: "name")
    tag.div(class: "d-flex align-items-center gap-1") do
      quick_field(kind, record, field, css: "fw-bold") +
        link_to(tag.i(class: "bi bi-box-arrow-up-right"), path, class: "text-muted small", title: "Abrir")
    end
  end

  # Casilla de selección en masa (se envía con el formulario #bulk-form de shared/_bulk_bar)
  def bulk_check(record)
    tag.input(type: "checkbox", name: "ids[]", value: record.respond_to?(:id) ? record.id : record, form: "bulk-form", class: "form-check-input",
      data: {bulk_actions_target: "row", action: "change->bulk-actions#rowChanged"})
  end

  def bulk_check_all
    tag.input(type: "checkbox", class: "form-check-input", title: "Seleccionar toda la página", data: {bulk_actions_target: "all", action: "change->bulk-actions#toggleAll"})
  end
end
