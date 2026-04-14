import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = [
    "propertiesList",
    "propertyTemplate",
    "specList",
    "specTemplate",
    "previewText",
  ];

  connect() {
    this.updatePreview();
  }

  // ───────── PROPERTIES ─────────

  addProperty() {
    this.propertiesListTarget.insertAdjacentHTML(
      "beforeend",
      this.propertyTemplateTarget.innerHTML,
    );
  }

  removeProperty(event) {
    event.currentTarget.closest(".spec-row").remove();
    this.updatePreview();
  }

  propertyChanged(event) {
    const select = event.currentTarget;
    const option = select.selectedOptions[0];

    if (!option) return;

    const propertyId = option.dataset.propertyId;
    if (!propertyId) return;

    // evitar duplicados
    const existing = this.propertiesListTarget.querySelectorAll("select[name]");
    for (let el of existing) {
      if (el !== select && el.name === `property_value_ids[${propertyId}]`) {
        alert("Esta propiedad ya fue agregada");
        select.value = "";
        return;
      }
    }

    // asignar name correcto
    select.name = `property_value_ids[${propertyId}]`;

    this.updatePreview();
  }

  // ───────── SPECS (LABELS) ─────────

  addSpec() {
    this.specListTarget.insertAdjacentHTML(
      "beforeend",
      this.specTemplateTarget.innerHTML,
    );
  }

  removeSpec(event) {
    event.currentTarget.closest(".spec-row").remove();
    this.updatePreview();
  }

  // ───────── PREVIEW ─────────

  updatePreview() {
    let lines = [];

    // base name
    const nameInput = this.element.querySelector(
      "input[name='supplier_item[name]']",
    );
    const baseName = nameInput?.value || "";

    // properties
    this.propertiesListTarget
      .querySelectorAll("select[name]")
      .forEach((select) => {
        const opt = select.selectedOptions[0];
        if (!opt) return;

        const group = opt.closest("optgroup")?.label;
        if (group && opt.value) {
          lines.push(`${group}: ${opt.text}`);
        }
      });

    // specs (labels sin valor aún)
    this.specListTarget
      .querySelectorAll("input[name='spec_labels[]']")
      .forEach((input) => {
        const label = input.value.trim();
        if (label) {
          lines.push(`${label}: ___`);
        }
      });

    // render final
    if (lines.length === 0) {
      this.previewTextTarget.textContent = baseName || "—";
    } else {
      this.previewTextTarget.textContent = `${baseName}\n` + lines.join("\n");
    }
  }
}
