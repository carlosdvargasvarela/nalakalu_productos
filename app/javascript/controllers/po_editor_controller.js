import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = [
    "itemRow",
    "quantity",
    "cost",
    "lineTotal",
    "grandTotal",
    "destroyCheck",
    "itemsContainer",
  ];

  connect() {
    this.calculate();
  }

  calculate() {
    let grand = 0;

    this.itemRowTargets.forEach((row) => {
      const destroyCheck = row.querySelector(
        "[data-po-editor-target='destroyCheck']",
      );
      if (destroyCheck?.value === "1") return;

      const qty =
        parseFloat(
          row.querySelector("[data-po-editor-target='quantity']")?.value,
        ) || 0;
      const cost =
        parseFloat(
          row.querySelector("[data-po-editor-target='cost']")?.value,
        ) || 0;
      const line = qty * cost;
      grand += line;

      const lineTotal = row.querySelector(
        "[data-po-editor-target='lineTotal']",
      );
      if (lineTotal) lineTotal.textContent = this.formatCurrency(line);
    });

    if (this.hasGrandTotalTarget) {
      this.grandTotalTarget.textContent = this.formatCurrency(grand);
    }
  }

  removeLine(event) {
    const row = event.currentTarget.closest(
      "[data-po-editor-target='itemRow']",
    );
    if (!row) return;

    const destroyCheck = row.querySelector(
      "[data-po-editor-target='destroyCheck']",
    );
    if (destroyCheck) destroyCheck.value = "1";

    row.style.opacity = "0.35";
    row.style.pointerEvents = "none";

    // Ocultar inputs para que no confundan al usuario
    row
      .querySelectorAll("input:not([type='hidden'])")
      .forEach((i) => (i.disabled = true));

    this.calculate();
  }

  formatCurrency(amount) {
    return (
      "₡" +
      amount.toLocaleString("es-CR", {
        minimumFractionDigits: 2,
        maximumFractionDigits: 2,
      })
    );
  }
}
