// app/javascript/controllers/purchase_order_discard_controller.js
import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static values = { url: String, confirm: String };

  discard(event) {
    event.preventDefault();

    if (this.confirmValue && !window.confirm(this.confirmValue)) return;

    fetch(this.urlValue, {
      method: "DELETE",
      headers: {
        "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]')
          .content,
        Accept: "text/vnd.turbo-stream.html",
      },
    })
      .then((response) => response.text())
      .then((html) => {
        // Deja que Turbo procese los streams devueltos por destroy
        // (cierra modal + refresca tarjeta del proveedor)
        window.Turbo.renderStreamMessage(html);
      });
  }
}
