// app/javascript/controllers/purchase_order_calculator_controller.js
import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = [
    "row",
    "qtyInput",
    "costInput",
    "rowTotal",
    "grandTotal",
    "destroyCheckbox",
  ];

  connect() {
    // Inicializar selects de unidad que ya tienen valor seleccionado
    this.element.querySelectorAll("[data-unit-select]").forEach((select) => {
      if (select.value) this.syncUnitCost(select);
    });
    this.calculateAll();
  }

  // Disparado cuando cambia el selector de unidad/precio
  onUnitChange(event) {
    this.syncUnitCost(event.target);
    this.calculateAll();
  }

  // Disparado cuando cambia qty o cost
  calculate() {
    this.calculateAll();
  }

  // Marca la fila para destruir y recalcula
  removeItem(event) {
    const btn = event.currentTarget;
    const row = btn.closest("[data-purchase-order-calculator-target='row']");
    const checkbox = row.querySelector(
      "[data-purchase-order-calculator-target='destroyCheckbox']",
    );

    if (checkbox) {
      checkbox.checked = true;
      row.classList.add("table-danger", "opacity-50");
      this.calculateAll();
    }
  }

  // --- Privados ---

  syncUnitCost(select) {
    const opt = select.selectedOptions[0];
    if (!opt) return;

    const cost = opt.dataset.cost;
    if (!cost) return;

    const row = select.closest("[data-purchase-order-calculator-target='row']");
    const costInput = row?.querySelector(
      "[data-purchase-order-calculator-target='costInput']",
    );
    if (costInput) costInput.value = parseFloat(cost).toFixed(2);
  }

  calculateAll() {
    let grand = 0;

    this.rowTargets.forEach((row) => {
      const destroyBox = row.querySelector(
        "[data-purchase-order-calculator-target='destroyCheckbox']",
      );
      if (destroyBox?.checked) return;

      const qty =
        parseFloat(
          row.querySelector(
            "[data-purchase-order-calculator-target='qtyInput']",
          )?.value,
        ) || 0;
      const cost =
        parseFloat(
          row.querySelector(
            "[data-purchase-order-calculator-target='costInput']",
          )?.value,
        ) || 0;
      const total = qty * cost;

      const totalEl = row.querySelector(
        "[data-purchase-order-calculator-target='rowTotal']",
      );
      if (totalEl) totalEl.textContent = this.fmt(total);

      grand += total;
    });

    if (this.hasGrandTotalTarget) {
      this.grandTotalTarget.textContent = this.fmt(grand);
    }
  }

  fmt(n) {
    return n.toLocaleString("es-CR", {
      minimumFractionDigits: 2,
      maximumFractionDigits: 2,
    });
  }
}
