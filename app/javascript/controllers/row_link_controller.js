import { Controller } from "@hotwired/stimulus"

// Fila de tabla clicable: abre el detalle salvo que el clic sea en un campo, enlace o botón.
export default class extends Controller {
  static values = { url: String }

  go(event) {
    if (event.target.closest("input, a, button, select, textarea, label")) return
    Turbo.visit(this.urlValue)
  }
}
