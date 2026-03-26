// app/javascript/controllers/procurement_controller.js
import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["checkbox", "submitBtn"];

  // Selecciona/Deselecciona todas las piezas de un pedido específico
  toggleOrder(event) {
    const orderNumber = event.target.dataset.order;
    const checked = event.target.checked;
    this.checkboxTargets.forEach((cb) => {
      if (cb.dataset.order === orderNumber) {
        cb.checked = checked;
      }
    });
    this.updateButton();
  }

  // Actualiza el estado del botón de generar OC
  updateButton() {
    const anyChecked = this.checkboxTargets.some((cb) => cb.checked);
    this.submitBtnTarget.disabled = !anyChecked;
  }
}
