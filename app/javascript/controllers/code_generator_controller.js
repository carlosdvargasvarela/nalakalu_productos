import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = [
    "productSelect",
    "variantsContainer",
    "result",
    "copyButton",
    "lineWarning",
  ];

  static values = {
    url: String,
  };

  connect() {
    this.baseCode = "";
    this.rules = [];
    this.selections = {};
    this.selections_ids = {};
  }

  loadProduct() {
    const productId = this.productSelectTarget.value;

    if (!productId) {
      this.reset();
      return;
    }

    fetch(`${this.urlValue}?product_id=${productId}`)
      .then((res) => res.json())
      .then((data) => {
        this.baseCode = data.base_code;
        this.rules = data.rules;
        this.selections = {};
        this.selections_ids = {};
        this.renderVariantSelectors();
        this.updateResult();
      })
      .catch((error) => {
        console.error("Error cargando producto:", error);
      });
  }

  renderVariantSelectors() {
    this.variantsContainerTarget.innerHTML = "";

    if (this.rules.length === 0) {
      this.variantsContainerTarget.innerHTML = `
        <div class="alert alert-light border text-muted">
          <i class="bi bi-info-circle me-2"></i>
          Este producto no requiere configuración de variantes.
        </div>
      `;
      return;
    }

    this.rules.forEach((rule, index) => {
      const wrapper = document.createElement("div");
      wrapper.classList.add("form-floating", "mb-3", "shadow-sm");

      const options = rule.variants
        .map(
          (v) =>
            `<option value="${v.id}" 
                     data-code="${v.code}" 
                     data-compatible='${JSON.stringify(v.compatible_with)}'>
              ${v.name}
            </option>`,
        )
        .join("");

      wrapper.innerHTML = `
        <select class="form-select" 
                id="rule_${rule.rule_id}"
                data-rule-id="${rule.rule_id}"
                data-action="change->code-generator#onVariantChange">
          <option value="">${rule.required ? "— Seleccione —" : "— Ninguno (Opcional) —"}</option>
          ${options}
        </select>
        <label for="rule_${rule.rule_id}">
          ${rule.variant_type_name} ${rule.required ? '<span class="text-danger">*</span>' : ""}
        </label>
      `;

      this.variantsContainerTarget.appendChild(wrapper);
    });
  }

  onVariantChange(event) {
    const select = event.target;
    const ruleId = select.dataset.ruleId;
    const selectedOption = select.selectedOptions[0];

    this.selections[ruleId] = selectedOption?.dataset.code || "";
    this.selections_ids[ruleId] = selectedOption?.value || null;

    this.filterOptions();
    this.updateResult();
  }

  filterOptions() {
    const selectedIds = Object.values(this.selections_ids)
      .filter((id) => id !== null && id !== "")
      .map((id) => parseInt(id));

    this.rules.forEach((rule) => {
      const select = this.variantsContainerTarget.querySelector(
        `select[data-rule-id="${rule.rule_id}"]`,
      );
      if (!select) return;

      Array.from(select.options).forEach((option) => {
        if (option.value === "") return;

        const compatibleWith = JSON.parse(option.dataset.compatible || "[]");
        const originalName =
          option.dataset.originalName ||
          option.text.replace(" (Incompatible)", "");

        if (!option.dataset.originalName)
          option.dataset.originalName = originalName;

        if (compatibleWith.length === 0) {
          option.disabled = false;
          option.text = originalName;
          return;
        }

        const isCompatible =
          selectedIds.length === 0 ||
          selectedIds.some((id) => compatibleWith.includes(id));
        option.disabled = !isCompatible;
        option.text = isCompatible
          ? originalName
          : `${originalName} (Incompatible)`;

        if (!isCompatible && option.selected) {
          select.value = "";
          this.selections[rule.rule_id] = "";
          this.selections_ids[rule.rule_id] = null;
        }
      });
    });
  }

  splitIntoLines(code, maxChars = 30) {
    const lines = [];
    for (let i = 0; i < code.length; i += maxChars) {
      lines.push(code.substring(i, i + maxChars));
    }
    return lines;
  }

  updateResult() {
    let code = this.baseCode;
    let allRequiredFilled = true;

    this.rules.forEach((rule) => {
      const part = this.selections[rule.rule_id];
      if (rule.required && !part) allRequiredFilled = false;
      if (part) code += `${rule.separator}${part}`;
    });

    if (!code) {
      this.resultTarget.value = "";
      this.copyButtonTarget.disabled = true;
      return;
    }

    const lines = this.splitIntoLines(code, 30);
    this.resultTarget.value = lines.slice(0, 5).join("\n");

    if (this.hasLineWarningTarget) {
      if (lines.length > 5) {
        this.lineWarningTarget.classList.remove("d-none");
        this.lineWarningTarget.innerHTML = `<i class="bi bi-exclamation-triangle me-2"></i> El código excede las 5 líneas permitidas.`;
      } else {
        this.lineWarningTarget.classList.add("d-none");
      }
    }

    this.copyButtonTarget.disabled = !allRequiredFilled;
  }

  copy() {
    const content = this.resultTarget.value;
    navigator.clipboard.writeText(content).then(() => {
      const originalText = this.copyButtonTarget.innerHTML;
      this.copyButtonTarget.innerHTML =
        '<i class="bi bi-check2-all"></i> ¡Copiado!';
      this.copyButtonTarget.classList.replace("btn-primary", "btn-success");
      setTimeout(() => {
        this.copyButtonTarget.innerHTML = originalText;
        this.copyButtonTarget.classList.replace("btn-success", "btn-primary");
      }, 2000);
    });
  }

  reset() {
    this.baseCode = "";
    this.rules = [];
    this.selections = {};
    this.selections_ids = {};
    this.variantsContainerTarget.innerHTML = "";
    this.resultTarget.value = "";
    this.copyButtonTarget.disabled = true;
    if (this.hasLineWarningTarget)
      this.lineWarningTarget.classList.add("d-none");
  }
}
