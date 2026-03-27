// app/javascript/controllers/origin_modal_controller.js
import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["modal"];

  connect() {
    // Inicializamos el modal de Bootstrap
    this.bsModal = new bootstrap.Modal(this.modalTarget);
  }

  open(event) {
    event.preventDefault();
    const url = event.currentTarget.dataset.url;

    // Cambiamos el src del turbo-frame dentro del modal
    const frame = document.getElementById("origin_order_modal_body");
    frame.src = url;

    // Mostramos el modal (el frame cargará el contenido automáticamente)
    this.bsModal.show();
  }
}
