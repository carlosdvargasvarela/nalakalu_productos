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
    "stockSalaWrapper",
  ];

  static values = {
    searchUrl: String,
    variantsUrl: String,
    maxChars: { type: Number, default: 30 },
    maxLines: { type: Number, default: 5 },
    prefixLength: { type: Number, default: 3 },
    usePrefixes: { type: Boolean, default: true },
    stockLabel: { type: String, default: "STOCK DE SALA" },
    defaultSeparator: { type: String, default: "-" },
  };

  connect() {
    this.baseCode = "";
    this.rules = [];
    this.selections = {};
    this.selections_ids = {};
    this.config = this._defaultConfig();

    this._outsideClick = (e) => {
      if (!this.searchWrapperTarget.contains(e.target)) this.closeDropdown();

      // Cerrar dropdowns de variantes si se hace click fuera
      document.querySelectorAll(".variant-dropdown-wrapper").forEach((w) => {
        if (!w.contains(e.target)) {
          w.querySelector(".variant-dropdown")?.classList.add("d-none");
        }
      });
    };
    document.addEventListener("click", this._outsideClick);
  }

  disconnect() {
    document.removeEventListener("click", this._outsideClick);
  }

  _defaultConfig() {
    return {
      max_chars: this.maxCharsValue,
      max_lines: this.maxLinesValue,
      prefix_length: this.prefixLengthValue,
      use_prefixes: this.usePrefixesValue,
      stock_label: this.stockLabelValue,
      default_separator: this.defaultSeparatorValue,
      show_stock_sala: true,
    };
  }

  _mergeConfig(serverSettings) {
    const defaults = this._defaultConfig();
    if (!serverSettings) return defaults;
    return {
      max_chars: serverSettings.max_chars ?? defaults.max_chars,
      max_lines: serverSettings.max_lines ?? defaults.max_lines,
      prefix_length: serverSettings.prefix_length ?? defaults.prefix_length,
      use_prefixes: serverSettings.use_prefixes ?? defaults.use_prefixes,
      stock_label: serverSettings.stock_label ?? defaults.stock_label,
      default_separator:
        serverSettings.default_separator ?? defaults.default_separator,
      show_stock_sala:
        serverSettings.show_stock_sala ?? defaults.show_stock_sala,
    };
  }

  // ─── BÚSQUEDA DE PRODUCTO ──────────────────────────────────────────────────

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
        {
          headers: { Accept: "application/json" },
        },
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
      list.innerHTML = `<div class="list-group-item text-muted small text-center py-3">Sin resultados.</div>`;
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
    this.reset();
  }

  closeDropdown() {
    this.searchDropdownTarget.classList.add("d-none");
  }

  // ─── CARGA DE VARIANTES ──────────────────────────────────────────────────────

  loadProduct(productId) {
    fetch(`${this.variantsUrlValue}?product_id=${productId}`)
      .then((res) => res.json())
      .then((data) => {
        this.baseCode = data.base_code || "";
        this.rules = data.rules || [];
        this.selections = {};
        this.selections_ids = {};
        this.config = this._mergeConfig(data.settings);

        if (this.hasStockSalaWrapperTarget) {
          this.stockSalaWrapperTarget.classList.toggle(
            "d-none",
            !this.config.show_stock_sala,
          );
        }

        this.renderVariantSelectors();
        this.updateResult();
      });
  }

  renderVariantSelectors() {
    this.variantsContainerTarget.innerHTML = "";

    if (this.rules.length === 0) {
      this.variantsContainerTarget.innerHTML = `<div class="alert alert-light border text-muted small"><i class="bi bi-info-circle me-2"></i>Sin variantes requeridas.</div>`;
      return;
    }

    this.rules.forEach((rule) => {
      const wrapper = document.createElement("div");
      wrapper.classList.add("mb-3");
      wrapper.dataset.ruleId = rule.rule_id;

      const optionsHtml = rule.variants
        .map(
          (v) => `
        <button type="button" class="list-group-item list-group-item-action px-3 py-2 variant-option"
                data-variant-id="${v.id}" data-display="${v.display_name}" data-compatible='${JSON.stringify(v.compatible_with)}'>
          ${v.name}
        </button>`,
        )
        .join("");

      wrapper.innerHTML = `
        <label class="form-label fw-semibold small text-secondary mb-1">
          ${rule.variant_type_name}${rule.required ? '<span class="text-danger ms-1">*</span>' : ""}
        </label>
        <div class="position-relative variant-dropdown-wrapper">
          <div class="input-group shadow-sm">
            <span class="input-group-text bg-white border-end-0"><i class="bi bi-search text-muted small"></i></span>
            <input type="text" class="form-control border-start-0 variant-search-input bg-white" 
                   placeholder="${rule.required ? "— Seleccione —" : "— Ninguno (Opcional) —"}" readonly>
            <button type="button" class="btn btn-outline-secondary border-start-0 variant-clear-btn d-none"><i class="bi bi-x-lg small"></i></button>
          </div>
          <div class="position-absolute w-100 z-3 d-none variant-dropdown" style="top: calc(100% + 4px);">
            <div class="card border-0 shadow rounded-3 overflow-hidden">
              <div class="p-2 border-bottom bg-light">
                <input type="text" class="form-control form-control-sm variant-filter-input" placeholder="Filtrar opciones...">
              </div>
              <div class="list-group list-group-flush variant-options-list" style="max-height: 200px; overflow-y: auto;">
                ${optionsHtml}
              </div>
            </div>
          </div>
        </div>`;

      const mainInput = wrapper.querySelector(".variant-search-input");
      const dropdown = wrapper.querySelector(".variant-dropdown");
      const filterInput = wrapper.querySelector(".variant-filter-input");
      const clearBtn = wrapper.querySelector(".variant-clear-btn");

      mainInput.addEventListener("click", () => {
        dropdown.classList.toggle("d-none");
        if (!dropdown.classList.contains("d-none")) filterInput.focus();
      });

      filterInput.addEventListener("input", () => {
        const q = filterInput.value.toLowerCase();
        wrapper.querySelectorAll(".variant-option").forEach((btn) => {
          btn.style.display = btn.textContent.toLowerCase().includes(q)
            ? ""
            : "none";
        });
      });

      wrapper.querySelectorAll(".variant-option").forEach((btn) => {
        btn.addEventListener("click", () => {
          mainInput.value = btn.textContent.trim();
          mainInput.dataset.selectedId = btn.dataset.variantId;
          clearBtn.classList.remove("d-none");
          dropdown.classList.add("d-none");
          this.selections[rule.rule_id] = btn.dataset.display;
          this.selections_ids[rule.rule_id] = btn.dataset.variantId;
          this.filterOptions();
          this.updateResult();
        });
      });

      clearBtn.addEventListener("click", (e) => {
        e.stopPropagation();
        mainInput.value = "";
        mainInput.dataset.selectedId = "";
        clearBtn.classList.add("d-none");
        this.selections[rule.rule_id] = "";
        this.selections_ids[rule.rule_id] = null;
        this.filterOptions();
        this.updateResult();
      });

      this.variantsContainerTarget.appendChild(wrapper);
    });
  }

  filterOptions() {
    const selectedIds = Object.values(this.selections_ids)
      .filter((id) => id)
      .map((id) => parseInt(id));

    this.rules.forEach((rule) => {
      const wrapper = this.variantsContainerTarget.querySelector(
        `[data-rule-id="${rule.rule_id}"]`,
      );
      if (!wrapper) return;

      wrapper.querySelectorAll(".variant-option").forEach((btn) => {
        const comp = JSON.parse(btn.dataset.compatible || "[]");
        const isComp =
          comp.length === 0 ||
          selectedIds.length === 0 ||
          selectedIds.some((id) => comp.includes(id));

        btn.classList.toggle("text-muted", !isComp);
        btn.classList.toggle("text-decoration-line-through", !isComp);
        btn.style.opacity = isComp ? "1" : "0.5";

        const mainInput = wrapper.querySelector(".variant-search-input");
        if (!isComp && mainInput.dataset.selectedId === btn.dataset.variantId) {
          mainInput.value = "";
          mainInput.dataset.selectedId = "";
          wrapper.querySelector(".variant-clear-btn").classList.add("d-none");
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

      let prefix = "";
      if (this.config.use_prefixes && rule.label) {
        prefix = `${rule.label.substring(0, this.config.prefix_length).toUpperCase()} `;
      }
      segments.push({
        text: `${prefix}${val}`.trim(),
        separator: rule.separator || this.config.default_separator,
      });
    });

    if (this.hasStockSalaTarget && this.stockSalaTarget.checked) {
      segments.push({
        text: this.config.stock_label,
        separator: this.config.default_separator,
      });
    }
    return segments;
  }

  wrapSegments(segments) {
    const lines = [];
    let currentLine = ""; // Empezamos con el código base

    const maxChars = parseInt(this.config.max_chars);
    const maxLines = parseInt(this.config.max_lines);

    segments.forEach((seg) => {
      const glue = seg.separator;
      const candidate =
        currentLine.length > 0 ? `${currentLine}${glue}${seg.text}` : seg.text;

      if (candidate.length <= maxChars) {
        currentLine = candidate;
      } else {
        lines.push(currentLine);
        currentLine = seg.text;
      }
    });
    if (currentLine) lines.push(currentLine);

    return { lines, overflowed: lines.length > maxLines };
  }

  updateResult() {
    let allRequiredFilled = true;
    this.rules.forEach((rule) => {
      if (rule.required && !this.selections[rule.rule_id])
        allRequiredFilled = false;
    });

    const segments = this.buildSegments();
    const wrapped = this.wrapSegments(segments);

    this.resultTarget.value = wrapped.lines.join("\n");

    if (this.hasLineWarningTarget) {
      const isOverflow = wrapped.lines.length > this.config.max_lines;
      this.lineWarningTarget.classList.toggle("d-none", !isOverflow);
      if (isOverflow) {
        this.lineWarningTarget.innerHTML = `<i class="bi bi-exclamation-triangle-fill me-2"></i>Excede las ${this.config.max_lines} líneas.`;
        this.copyButtonTarget.disabled = true;
        return;
      }
    }

    this.copyButtonTarget.disabled =
      !allRequiredFilled || segments.length === 0;
  }

  copy() {
    navigator.clipboard.writeText(this.resultTarget.value).then(() => {
      const btn = this.copyButtonTarget;
      const oldText = btn.innerHTML;
      btn.innerHTML = '<i class="bi bi-check2-all me-2"></i>¡Copiado!';
      btn.classList.replace("btn-primary", "btn-success");
      setTimeout(() => {
        btn.innerHTML = oldText;
        btn.classList.replace("btn-success", "btn-primary");
      }, 2000);
    });
  }

  reset() {
    this.baseCode = "";
    this.rules = [];
    this.selections = {};
    this.selections_ids = {};
    this.variantsContainerTarget.innerHTML = `<div class="text-muted small p-3 border rounded-3 bg-light text-center">Seleccione un producto primero.</div>`;
    this.resultTarget.value = "";
    this.copyButtonTarget.disabled = true;
    if (this.hasLineWarningTarget)
      this.lineWarningTarget.classList.add("d-none");
    if (this.hasStockSalaTarget) this.stockSalaTarget.checked = false;
  }
}
