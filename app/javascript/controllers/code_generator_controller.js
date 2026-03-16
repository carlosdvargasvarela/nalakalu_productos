// app/javascript/controllers/code_generator_controller.js
import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = [
    "searchInput",
    "searchDropdown",
    "searchResults",
    "searchIcon",
    "searchWrapper",
    "selectedProduct",
    "selectedProductName",
    "selectedProductCode",
    "variantsContainer",
    "result",
    "copyButton",
    "lineWarning",
    "stockSala",
  ];

  static values = {
    searchUrl: String,
    variantsUrl: String,
  };

  connect() {
    this.baseCode = "";
    this.rules = [];
    this.selections = {}; // ruleId -> display_name de la variante
    this.selections_ids = {}; // ruleId -> id de la variante
    this.searchTimeout = null;

    this._outsideClick = (e) => {
      if (!this.searchWrapperTarget.contains(e.target)) this.closeDropdown();
    };
    document.addEventListener("click", this._outsideClick);
  }

  disconnect() {
    document.removeEventListener("click", this._outsideClick);
  }

  // ─── BÚSQUEDA ────────────────────────────────────────────────────────────────

  onSearchInput() {
    const query = this.searchInputTarget.value.trim();
    clearTimeout(this.searchTimeout);
    if (query.length < 2) {
      this.closeDropdown();
      return;
    }
    this.searchTimeout = setTimeout(() => this.fetchProducts(query), 300);
  }

  onSearchFocus() {
    const query = this.searchInputTarget.value.trim();
    if (query.length >= 2) this.fetchProducts(query);
  }

  onSearchKeydown(event) {
    if (event.key === "Escape") this.closeDropdown();
  }

  async fetchProducts(query) {
    this.searchIconTarget.className = "bi bi-arrow-repeat text-muted spin";
    try {
      const res = await fetch(
        `${this.searchUrlValue}?q=${encodeURIComponent(query)}`,
        { headers: { Accept: "application/json" } },
      );
      const products = await res.json();
      this.renderDropdown(products);
    } catch (e) {
      console.error("Error buscando productos:", e);
    } finally {
      this.searchIconTarget.className = "bi bi-search text-muted";
    }
  }

  renderDropdown(products) {
    const list = this.searchResultsTarget;
    list.innerHTML = "";

    if (products.length === 0) {
      list.innerHTML = `
        <div class="list-group-item text-muted small text-center py-3">
          <i class="bi bi-emoji-frown me-1"></i>Sin resultados. Intenta con otro término.
        </div>`;
    } else {
      products.forEach((product) => {
        const item = document.createElement("button");
        item.type = "button";
        item.className =
          "list-group-item list-group-item-action d-flex justify-content-between align-items-center py-3 px-4";
        item.innerHTML = `
          <div>
            <div class="fw-bold text-dark">${product.name}</div>
            <code class="text-muted small">${product.base_code || ""}</code>
          </div>
          <i class="bi bi-chevron-right text-muted"></i>`;
        item.addEventListener("click", () => this.selectProduct(product));
        list.appendChild(item);
      });
    }

    this.searchDropdownTarget.classList.remove("d-none");
  }

  selectProduct(product) {
    this.closeDropdown();
    this.searchInputTarget.value = "";
    this.searchWrapperTarget
      .querySelector(".input-group")
      .classList.add("d-none");
    this.selectedProductTarget.classList.remove("d-none");
    this.selectedProductNameTarget.textContent = product.name;
    this.selectedProductCodeTarget.textContent = product.base_code || "";
    this.loadProduct(product.id);
  }

  clearProduct() {
    this.searchWrapperTarget
      .querySelector(".input-group")
      .classList.remove("d-none");
    this.selectedProductTarget.classList.add("d-none");
    this.searchInputTarget.value = "";
    this.searchInputTarget.focus();
    this.reset();
  }

  closeDropdown() {
    this.searchDropdownTarget.classList.add("d-none");
  }

  // ─── CARGA DE VARIANTES ──────────────────────────────────────────────────────

  loadProduct(productId) {
    if (!productId) {
      this.reset();
      return;
    }

    fetch(`${this.variantsUrlValue}?product_id=${productId}`)
      .then((res) => res.json())
      .then((data) => {
        this.baseCode = data.base_code || "";
        this.rules = data.rules || [];
        this.selections = {};
        this.selections_ids = {};
        this.renderVariantSelectors();
        this.updateResult();
      })
      .catch((error) => console.error("Error cargando producto:", error));
  }

  renderVariantSelectors() {
    this.variantsContainerTarget.innerHTML = "";

    if (this.rules.length === 0) {
      this.variantsContainerTarget.innerHTML = `
        <div class="alert alert-light border text-muted">
          <i class="bi bi-info-circle me-2"></i>
          Este producto no requiere configuración de variantes.
        </div>`;
      return;
    }

    this.rules.forEach((rule) => {
      const wrapper = document.createElement("div");
      wrapper.classList.add("form-floating", "mb-3", "shadow-sm");

      const options = rule.variants
        .map(
          (v) =>
            `<option value="${v.id}"
                    data-code="${v.code || ""}"
                    data-display="${v.display_name}"
                    data-compatible='${JSON.stringify(v.compatible_with)}'>
              ${v.name}
            </option>`,
        )
        .join("");

      const requiredMark = rule.required
        ? '<span class="text-danger"></span>'
        : "";

      wrapper.innerHTML = `
        <select class="form-select"
                id="rule_${rule.rule_id}"
                data-rule-id="${rule.rule_id}"
                data-action="change->code-generator#onVariantChange">
          <option value="">${rule.required ? "— Seleccione —" : "— Ninguno (Opcional) —"}</option>
          ${options}
        </select>
        <label for="rule_${rule.rule_id}">
          ${rule.variant_type_name} ${requiredMark}
        </label>`;

      this.variantsContainerTarget.appendChild(wrapper);
    });
  }

  // ─── SELECCIÓN Y FILTRADO ────────────────────────────────────────────────────

  onVariantChange(event) {
    const select = event.target;
    const ruleId = select.dataset.ruleId;
    const selectedOption = select.selectedOptions[0];

    // Guardamos el display_name de la VARIANTE para construir el código
    this.selections[ruleId] = selectedOption?.dataset.display || "";
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

        // Si la variante no declara compatibilidades, siempre está disponible
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

        // Si la opción seleccionada se vuelve incompatible, la limpiamos
        if (!isCompatible && option.selected) {
          select.value = "";
          this.selections[rule.rule_id] = "";
          this.selections_ids[rule.rule_id] = null;
        }
      });
    });
  }

  // ─── CONSTRUCCIÓN DEL CÓDIGO ─────────────────────────────────────────────────

  buildSegments() {
    const segments = [];

    this.rules.forEach((rule) => {
      const val = this.selections[rule.rule_id];
      if (!val) return;

      // El prefijo de label (ej: "Sobre" -> "SOB ") solo si el label existe
      const prefix = rule.label
        ? `${rule.label.substring(0, 3).toUpperCase()} `
        : "";

      segments.push({
        text: `${prefix}${val}`.trim(),
        separator: rule.separator || "-",
      });
    });

    // Situación 3: Stock de Sala al final
    if (this.hasStockSalaTarget && this.stockSalaTarget.checked) {
      segments.push({
        text: "STOCK DE SALA",
        separator: "-",
      });
    }

    return segments;
  }

  wrapSegments(segments, maxChars = 30, maxLines = 5) {
    const lines = [];
    let currentLine = ""; // ← Sin baseCode

    segments.forEach((seg) => {
      const glue = seg.separator || "-";
      const candidate =
        currentLine.length > 0 ? `${currentLine}${glue}${seg.text}` : seg.text; // ← Primera línea arranca directo con el segmento

      if (candidate.length <= maxChars) {
        currentLine = candidate;
      } else {
        if (currentLine.length > 0) lines.push(currentLine);
        currentLine = seg.text;
      }
    });

    if (currentLine.length > 0) lines.push(currentLine);

    return {
      lines,
      overflowed: lines.length > maxLines,
    };
  }

  updateResult() {
    let allRequiredFilled = true;
    this.rules.forEach((rule) => {
      if (rule.required && !this.selections[rule.rule_id]) {
        allRequiredFilled = false;
      }
    });

    const segments = this.buildSegments();
    const wrapped = this.wrapSegments(segments, 30, 5);

    this.resultTarget.value = wrapped.lines.join("\n");

    // Manejo de advertencias
    if (this.hasLineWarningTarget) {
      if (wrapped.overflowed) {
        this.lineWarningTarget.classList.remove("d-none");
        this.lineWarningTarget.innerHTML = `<i class="bi bi-exclamation-triangle-fill me-2"></i> El código excede las 5 líneas del CRM.`;
        this.copyButtonTarget.disabled = true;
        return;
      } else {
        this.lineWarningTarget.classList.add("d-none");
      }
    }

    this.copyButtonTarget.disabled =
      !allRequiredFilled || segments.length === 0;
  }

  // ─── COPIAR ──────────────────────────────────────────────────────────────────

  copy() {
    const content = this.resultTarget.value;
    if (!content) return;

    navigator.clipboard.writeText(content).then(() => {
      const originalHTML = this.copyButtonTarget.innerHTML;
      this.copyButtonTarget.innerHTML =
        '<i class="bi bi-check2-all me-2"></i>¡Copiado!';
      this.copyButtonTarget.classList.replace("btn-primary", "btn-success");
      setTimeout(() => {
        this.copyButtonTarget.innerHTML = originalHTML;
        this.copyButtonTarget.classList.replace("btn-success", "btn-primary");
      }, 2000);
    });
  }

  // ─── RESET ───────────────────────────────────────────────────────────────────

  reset() {
    this.baseCode = "";
    this.rules = [];
    this.selections = {};
    this.selections_ids = {};
    this.variantsContainerTarget.innerHTML = `
      <div class="text-muted small p-3 border rounded-3 bg-light text-center">
        <i class="bi bi-arrow-up-circle me-1"></i>Seleccione un producto primero.
      </div>`;
    this.resultTarget.value = "";
    this.copyButtonTarget.disabled = true;
    if (this.hasLineWarningTarget)
      this.lineWarningTarget.classList.add("d-none");
    if (this.hasStockSalaTarget) this.stockSalaTarget.checked = false;
  }
}
