// app/javascript/controllers/stock_options_controller.js
import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["list", "item"];

  add() {
    const item = document.createElement("div");
    item.className = "input-group";
    item.dataset.stockOptionsTarget = "item";
    item.innerHTML = `
      <span class="input-group-text bg-white">
        <i class="bi bi-box-seam text-muted"></i>
      </span>
      <input type="text"
             name="code_setting[stock_sala_options][]"
             class="form-control"
             placeholder="Ej: STOCK DE SALA">
      <button type="button"
              class="btn btn-outline-danger"
              data-action="click->stock-options#remove">
        <i class="bi bi-trash"></i>
      </button>`;
    this.listTarget.appendChild(item);
    item.querySelector("input").focus();
  }

  remove(event) {
    const item = event.currentTarget.closest(
      "[data-stock-options-target='item']",
    );
    // Mantener al menos una opción
    if (this.itemTargets.length > 1) {
      item.remove();
    } else {
      item.querySelector("input").value = "";
    }
  }
}
