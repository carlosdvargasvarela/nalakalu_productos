import { Controller } from "@hotwired/stimulus"

// Guarda un campo al salir de él (change). Verde = guardado, rojo = error (el motivo queda en el tooltip).
export default class extends Controller {
  static values = { url: String, field: String }

  connect() { this.saved = this.element.value }

  async save() {
    const value = this.element.value
    if (value === this.saved) return
    this.element.classList.remove("is-valid", "is-invalid")
    const response = await fetch(this.urlValue, {
      method: "PATCH",
      headers: { "Content-Type": "application/json", Accept: "application/json", "X-CSRF-Token": document.querySelector("meta[name=csrf-token]")?.content },
      body: JSON.stringify({ field: this.fieldValue, value })
    })
    const data = await response.json().catch(() => ({}))
    if (response.ok) {
      this.saved = value
      this.element.classList.add("is-valid")
      this.element.title = "Guardado"
      setTimeout(() => this.element.classList.remove("is-valid"), 1500)
    } else {
      this.element.classList.add("is-invalid")
      this.element.title = data.error || "No se pudo guardar"
    }
  }
}
