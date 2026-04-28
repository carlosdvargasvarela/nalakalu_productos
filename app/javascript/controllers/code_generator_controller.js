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
      document.querySelectorAll(".variant-dropdown-wrapper").forEach((w) => {
        if (!w.contains(e.target))
          w.querySelector(".variant-dropdown")?.classList.add("d-none");
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
      stock_options: ["STOCK DE SALA"], // ← array por defecto
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
      stock_options: serverSettings.stock_options?.length
        ? serverSettings.stock_options
        : defaults.stock_options,
      default_separator:
        serverSettings.default_separator ?? defaults.default_separator,
      show_stock_sala:
        serverSettings.show_stock_sala ?? defaults.show_stock_sala,
    };
  }

  // ─── BÚSQUEDA ──────────────────────────────────────────────────────────────

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
      this.renderDropdown(await res.json());
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

  // ─── CARGA DE VARIANTES ────────────────────────────────────────────────────

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
      this.variantsContainerTarget.innerHTML = `
        <div class="alert alert-light border text-muted small">
          <i class="bi bi-info-circle me-2"></i>Sin variantes requeridas.
        </div>`;
      return;
    }

    this.rules.forEach((rule) => {
      const wrapper = document.createElement("div");
      wrapper.classList.add("mb-3");
      wrapper.dataset.ruleId = rule.rule_id;

      // ── Regla fantasma: tipo global keep_position que el producto no tiene ──
      if (rule.ghost) {
        wrapper.innerHTML = `
          <label class="form-label fw-semibold small text-secondary mb-1 opacity-50">
            ${rule.variant_type_name}
            <span class="badge bg-secondary-subtle text-secondary border ms-2"
                  style="font-size:0.65rem;"
                  title="Este producto no usa este tipo de variante, pero se reserva su posición en el código">
              <i class="bi bi-pin-angle"></i> Posición reservada
            </span>
          </label>
          <div class="input-group shadow-sm opacity-50">
            <span class="input-group-text bg-light border-end-0">
              <i class="bi bi-dash-circle text-muted small"></i>
            </span>
            <input type="text"
                   class="form-control border-start-0 bg-light text-muted fst-italic"
                   placeholder="— No aplica para este producto —"
                   disabled>
          </div>`;
        this.variantsContainerTarget.appendChild(wrapper);
        return; // sin event listeners
      }

      // ── Regla normal ───────────────────────────────────────────────────────
      const keepPositionBadge = rule.keep_position
        ? `<span class="badge bg-info-subtle text-info border border-info ms-2"
               style="font-size:0.65rem;"
               title="Si no se selecciona, se reserva el espacio en el código">
             <i class="bi bi-pin-angle"></i> Posición fija
           </span>`
        : "";

      const optionsHtml = rule.variants
        .map(
          (v) => `
        <button type="button"
                class="list-group-item list-group-item-action px-3 py-2 variant-option"
                data-variant-id="${v.id}"
                data-display="${v.display_name || v.name}"
                data-compatible='${JSON.stringify(v.compatible_with || [])}'>
          ${v.name}
        </button>`,
        )
        .join("");

      wrapper.innerHTML = `
        <label class="form-label fw-semibold small text-secondary mb-1">
          ${rule.variant_type_name}
          ${rule.required ? '<span class="text-danger ms-1">*</span>' : ""}
          ${keepPositionBadge}
        </label>
        <div class="position-relative variant-dropdown-wrapper">
          <div class="input-group shadow-sm">
            <span class="input-group-text bg-white border-end-0">
              <i class="bi bi-search text-muted small"></i>
            </span>
            <input type="text"
                   class="form-control border-start-0 variant-search-input bg-white"
                   placeholder="${rule.required ? "— Seleccione —" : "— Ninguno (Opcional) —"}"
                   readonly>
            <button type="button"
                    class="btn btn-outline-secondary border-start-0 variant-clear-btn d-none">
              <i class="bi bi-x-lg small"></i>
            </button>
          </div>
          <div class="position-absolute w-100 z-3 d-none variant-dropdown"
               style="top: calc(100% + 4px);">
            <div class="card border-0 shadow rounded-3 overflow-hidden">
              <div class="p-2 border-bottom bg-light">
                <input type="text"
                       class="form-control form-control-sm variant-filter-input"
                       placeholder="Filtrar opciones...">
              </div>
              <div class="list-group list-group-flush variant-options-list"
                   style="max-height: 200px; overflow-y: auto;">
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
          this.selections[rule.rule_id] = btn.dataset.display.trim();
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
      .filter(Boolean)
      .map((id) => parseInt(id));

    this.rules.forEach((rule) => {
      if (rule.ghost) return; // las fantasmas no tienen opciones

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

  // ─── CONSTRUCCIÓN DEL CÓDIGO ───────────────────────────────────────────────

  buildTokens() {
    const sep = this.config.default_separator;
    const prefixLen = parseInt(this.config.prefix_length) || 3;
    const tokens = [];

    this.rules.forEach((rule) => {
      // Fantasma: tipo global keep_position que el producto no tiene
      // → reserva posición silenciosa (no genera texto visible)
      if (rule.ghost) {
        tokens.push("");
        return;
      }

      const val = (this.selections[rule.rule_id] || "").trim().toUpperCase();
      const glue = (rule.separator || sep).trim();
      const hasValue = val !== "";

      // Opcional sin valor → omitir completamente (no reserva posición)
      if (!hasValue && !rule.keep_position && !rule.required) {
        tokens.push(null);
        return;
      }

      let token = "";

      if (this.config.use_prefixes && rule.label && rule.label.trim() !== "") {
        const prefix = rule.label.trim().substring(0, prefixLen).toUpperCase();
        // Con valor: "TE-SEDA" | Sin valor (posición reservada): "TE-"
        token = hasValue ? `${prefix}${glue}${val}` : `${prefix}${glue}`;
      } else {
        // Sin prefijo: solo el valor, o vacío si es posición reservada sin label
        token = val;
      }

      tokens.push(token);
    });

    // Stock de Sala al final
    if (this.hasStockSalaTarget && this.stockSalaTarget.value) {
      tokens.push(this.stockSalaTarget.value.toUpperCase());
    }

    return tokens;
  }

  buildCode() {
    const sep = this.config.default_separator;
    const maxChars = parseInt(this.config.max_chars);
    const maxLines = parseInt(this.config.max_lines);

    const activeTokens = this.buildTokens().filter((t) => t !== null);

    const lines = [];
    let current = "";

    activeTokens.forEach((token) => {
      // Token vacío = posición reservada → forzar línea vacía
      if (token === "") {
        if (current !== "") lines.push(current);
        lines.push(""); // línea vacía reservada
        current = "";
        return;
      }

      const candidate = current === "" ? token : `${current}${sep}${token}`;

      if (candidate.length <= maxChars) {
        current = candidate;
      } else {
        if (current !== "") lines.push(current);
        current = token;
      }
    });

    if (current !== "") lines.push(current);

    return { lines, overflowed: lines.length > maxLines };
  }

  updateResult() {
    let allRequiredFilled = true;
    this.rules.forEach((rule) => {
      if (
        rule.required &&
        !rule.ghost && // las fantasmas nunca bloquean
        (!this.selections[rule.rule_id] ||
          this.selections[rule.rule_id].trim() === "")
      ) {
        allRequiredFilled = false;
      }
    });

    const { lines, overflowed } = this.buildCode();
    this.resultTarget.value = lines.join("\n");

    if (this.hasLineWarningTarget) {
      this.lineWarningTarget.classList.toggle("d-none", !overflowed);
      if (overflowed) {
        this.lineWarningTarget.innerHTML = `
          <i class="bi bi-exclamation-triangle-fill me-2"></i>
          Excede las ${this.config.max_lines} líneas.`;
        this.copyButtonTarget.disabled = true;
        return;
      }
    }

    // Habilitar copiar solo si hay al menos un token real y todos los requeridos están llenos
    const hasAnyToken = this.buildTokens().some((t) => t !== null && t !== "");
    this.copyButtonTarget.disabled = !allRequiredFilled || !hasAnyToken;
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
    this.variantsContainerTarget.innerHTML = `
      <div class="text-muted small p-3 border rounded-3 bg-light text-center">
        Seleccione un producto primero.
      </div>`;
    this.resultTarget.value = "";
    this.copyButtonTarget.disabled = true;
    if (this.hasLineWarningTarget)
      this.lineWarningTarget.classList.add("d-none");
    if (this.hasStockSalaTarget) this.stockSalaTarget.checked = false;
  }
}
