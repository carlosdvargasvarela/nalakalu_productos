import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = [
    "previewText",
    "propertiesList",
    "propertyTemplate",
    "specList",
    "specTemplate",
  ];

  connect() {
    this.normalizeExistingPropertyInputs();
    this.updatePreview();
  }

  addProperty() {
    const content = this.propertyTemplateTarget.content.cloneNode(true);
    this.propertiesListTarget.appendChild(content);
    this.updatePreview();
  }

  removeProperty(event) {
    const row = event.currentTarget.closest(".spec-row");
    if (row) row.remove();
    this.updatePreview();
  }

  propertyChanged(event) {
    const select = event.currentTarget;
    const selectedOption = select.options[select.selectedIndex];
    const propertyId = selectedOption?.dataset?.propertyId;

    if (propertyId) {
      select.name = `property_value_ids[${propertyId}]`;
    } else {
      select.name = "";
    }

    this.updatePreview();
  }

  addSpec() {
    const content = this.specTemplateTarget.content.cloneNode(true);
    this.specListTarget.appendChild(content);
    this.updatePreview();
  }

  removeSpec(event) {
    const row = event.currentTarget.closest(".spec-row");
    if (row) row.remove();
    this.updatePreview();
  }

  updatePreview() {
    if (!this.hasPreviewTextTarget) return;

    const name = this.fieldValue('input[name="supplier_item[name]"]');
    const sku = this.fieldValue('input[name="supplier_item[sku]"]');
    const unit = this.fieldValue('select[name="supplier_item[unit]"]');

    const propertyLines = this.collectPropertyLines();
    const specLabels = this.collectSpecLabels();

    const lines = [];
    lines.push(name || "—");

    if (sku) lines.push(`SKU: ${sku}`);
    if (unit) lines.push(`Unidad: ${unit}`);
    if (propertyLines.length > 0)
      lines.push(`Propiedades: ${propertyLines.join(" | ")}`);
    if (specLabels.length > 0)
      lines.push(`Specs permitidas: ${specLabels.join(", ")}`);

    this.previewTextTarget.textContent = lines.join("\n");
  }

  normalizeExistingPropertyInputs() {
    if (!this.hasPropertiesListTarget) return;

    const dynamicSelects = this.propertiesListTarget.querySelectorAll(
      ".property-group-select",
    );
    dynamicSelects.forEach((select) => this.assignPropertyName(select));
  }

  assignPropertyName(select) {
    const selectedOption = select.options[select.selectedIndex];
    const propertyId = selectedOption?.dataset?.propertyId;

    if (propertyId) {
      select.name = `property_value_ids[${propertyId}]`;
    }
  }

  collectPropertyLines() {
    if (!this.hasPropertiesListTarget) return [];

    const selects = Array.from(
      this.propertiesListTarget.querySelectorAll("select"),
    );

    return selects
      .map((select) => {
        const selectedOption = select.options[select.selectedIndex];
        if (!selectedOption || !selectedOption.value) return null;

        let propertyName = "Propiedad";

        if (
          selectedOption.parentElement &&
          selectedOption.parentElement.tagName === "OPTGROUP"
        ) {
          propertyName = selectedOption.parentElement.label;
        } else {
          const label = select
            .closest(".spec-row")
            ?.querySelector("label.form-label");
          if (label) propertyName = label.textContent.trim();
        }

        return `${propertyName}: ${selectedOption.textContent.trim()}`;
      })
      .filter(Boolean);
  }

  collectSpecLabels() {
    if (!this.hasSpecListTarget) return [];

    return Array.from(
      this.specListTarget.querySelectorAll('input[name="spec_labels[]"]'),
    )
      .map((input) => input.value.trim())
      .filter((value) => value.length > 0);
  }

  fieldValue(selector) {
    const field = this.element.querySelector(selector);
    return field ? field.value.trim() : "";
  }
}
