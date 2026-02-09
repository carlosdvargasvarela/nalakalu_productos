import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = [
    "productSelect",
    "variantsContainer",
    "result",
    "copyButton",
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
        alert(
          "Hubo un error al cargar el producto. Por favor intenta de nuevo."
        );
      });
  }

  renderVariantSelectors() {
    this.variantsContainerTarget.innerHTML = "";

    if (this.rules.length === 0) {
      this.variantsContainerTarget.innerHTML = `
        <div class="alert alert-warning">
          <i class="bi bi-exclamation-triangle"></i>
          Este producto no tiene variantes configuradas.
        </div>
      `;
      return;
    }

    this.rules.forEach((rule, index) => {
      const wrapper = document.createElement("div");
      wrapper.classList.add("mb-3");
      wrapper.dataset.ruleId = rule.rule_id;

      const requiredBadge = rule.required
        ? '<span class="badge bg-danger ms-2">Obligatorio</span>'
        : '<span class="badge bg-secondary ms-2">Opcional</span>';

      wrapper.innerHTML = `
        <label class="form-label fw-bold">
          ${index + 2}️⃣ ${rule.variant_type_name}
          ${requiredBadge}
        </label>

        <select class="form-select form-select-lg"
                data-rule-id="${rule.rule_id}"
                data-action="change->code-generator#onVariantChange">
          <option value="" data-code="">
            ${
              rule.required
                ? "— Seleccione una opción —"
                : "— Ninguno (Opcional) —"
            }
          </option>
          ${rule.variants
            .map(
              (v) =>
                `<option value="${v.id}" 
                     data-code="${v.code}" 
                     data-compatible='${JSON.stringify(v.compatible_with)}'>
              ${v.name}
            </option>`
            )
            .join("")}
        </select>
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

    if (selectedIds.length === 0) {
      this.showAllOptions();
      return;
    }

    this.rules.forEach((rule) => {
      const select = this.variantsContainerTarget.querySelector(
        `select[data-rule-id="${rule.rule_id}"]`
      );
      if (!select) return;

      Array.from(select.options).forEach((option) => {
        if (option.value === "") {
          option.disabled = false;
          option.hidden = false;
          return;
        }

        const compatibleWith = JSON.parse(option.dataset.compatible || "[]");
        const originalName =
          option.dataset.originalName || option.text.split(" (")[0];

        if (!option.dataset.originalName) {
          option.dataset.originalName = originalName;
        }

        if (compatibleWith.length === 0) {
          option.disabled = false;
          option.hidden = false;
          option.text = originalName;
          return;
        }

        const isCompatible = selectedIds.some((id) =>
          compatibleWith.includes(id)
        );

        option.disabled = !isCompatible;
        option.hidden = !isCompatible;

        if (!isCompatible) {
          option.text = `${originalName} (Incompatible)`;
          if (option.selected) {
            select.value = "";
            this.selections[rule.rule_id] = "";
            this.selections_ids[rule.rule_id] = null;
          }
        } else {
          option.text = originalName;
        }
      });
    });
  }

  showAllOptions() {
    const selects = this.variantsContainerTarget.querySelectorAll("select");
    selects.forEach((select) => {
      Array.from(select.options).forEach((option) => {
        const originalName =
          option.dataset.originalName || option.text.split(" (")[0];
        option.disabled = false;
        option.hidden = false;
        option.text = originalName;
      });
    });
  }

  updateResult() {
    let code = this.baseCode;
    let allRequiredFilled = true;

    this.rules.forEach((rule) => {
      const part = this.selections[rule.rule_id];

      if (rule.required && !part) {
        allRequiredFilled = false;
      }

      if (part) {
        code += `${rule.separator}${part}`;
      }
    });

    this.resultTarget.textContent = code || "—";
    this.copyButtonTarget.disabled = !allRequiredFilled;

    if (allRequiredFilled) {
      this.resultTarget.classList.remove("text-muted");
      this.resultTarget.classList.add("text-success");
    } else {
      this.resultTarget.classList.remove("text-success");
      this.resultTarget.classList.add("text-muted");
    }
  }

  copy() {
    const code = this.resultTarget.textContent;

    navigator.clipboard
      .writeText(code)
      .then(() => {
        this.copyButtonTarget.innerHTML =
          '<i class="bi bi-check-circle"></i> ¡Copiado!';
        this.copyButtonTarget.classList.remove("btn-success");
        this.copyButtonTarget.classList.add("btn-primary");

        setTimeout(() => {
          this.copyButtonTarget.innerHTML =
            '<i class="bi bi-clipboard"></i> Copiar Código';
          this.copyButtonTarget.classList.remove("btn-primary");
          this.copyButtonTarget.classList.add("btn-success");
        }, 2000);
      })
      .catch((err) => {
        console.error("Error al copiar:", err);
        alert("No se pudo copiar el código. Por favor, cópialo manualmente.");
      });
  }

  reset() {
    this.baseCode = "";
    this.rules = [];
    this.selections = {};
    this.selections_ids = {};
    this.variantsContainerTarget.innerHTML = "";
    this.resultTarget.textContent = "—";
    this.copyButtonTarget.disabled = true;
  }
}
