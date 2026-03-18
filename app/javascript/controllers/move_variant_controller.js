// app/javascript/controllers/move_variant_controller.js
import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["modal"];

  connect() {
    this.modal = new bootstrap.Modal(this.modalTarget);
  }

  disconnect() {
    this.modal?.dispose();
  }

  open(event) {
    event.preventDefault();
    this.modal.show();
  }

  close() {
    this.modal.hide();
  }
}
