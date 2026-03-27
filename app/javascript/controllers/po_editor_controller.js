// app/javascript/controllers/po_editor_controller.js
import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = [
    "quantity",
    "cost",
    "lineTotal",
    "grandTotal",
    "destroyCheck",
    "itemRow",
  ];

  connect() {
    this.calculate();
  }

  calculate() {
    let grand = 0;

    this.quantityTargets.forEach((qtyInput, i) => {
      const row = qtyInput.closest("[data-po-editor-target~='itemRow']");
      const destroyed = row?.querySelector("input[name*='_destroy']")?.checked;

      if (destroyed) {
        this.lineTotalTargets[i].textContent = "—";
        return;
      }

      const qty = parseFloat(qtyInput.value) || 0;
      const cost = parseFloat(this.costTargets[i].value) || 0;
      const total = qty * cost;

      this.lineTotalTargets[i].textContent = this.formatCRC(total);
      grand += total;
    });

    this.grandTotalTarget.textContent = this.formatCRC(grand);
  }

  toggleDestroy(event) {
    const row = event.target.closest("[data-po-editor-target~='itemRow']");
    if (row) row.classList.toggle("opacity-50", event.target.checked);
    this.calculate();
  }

  formatCRC(value) {
    return new Intl.NumberFormat("es-CR", {
      style: "currency",
      currency: "CRC",
      minimumFractionDigits: 2,
    }).format(value);
  }
}
