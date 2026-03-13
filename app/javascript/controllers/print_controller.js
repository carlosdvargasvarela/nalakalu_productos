// app/javascript/controllers/print_controller.js
import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  print() {
    window.print();
  }

  closeModal() {
    const modal = document.getElementById("remote_modal");
    modal.innerHTML = ""; // Limpia el frame y cierra el modal visualmente
    // Opcional: remover clases de bootstrap si quedan pegadas
    document.body.classList.remove("modal-open");
  }
}
