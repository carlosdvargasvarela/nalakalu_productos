import { Controller } from "@hotwired/stimulus"

// Dos listas: "se quedan" y "se van". Un clic en una fila la pasa a la otra lista;
// solo las filas de "se van" envían su id (input hidden habilitado).
export default class extends Controller {
  static targets = ["stay", "go", "stayCount", "goCount", "search"]

  connect() { this.refresh() }

  toggle(event) {
    const row = event.currentTarget.closest("[data-row]")
    this.send(row, row.parentElement === this.stayTarget)
    this.refresh()
  }

  moveAll(event) { this.moveAllTo(event.params.dir === "go") }

  // Unir: todo al destino existente y ocultar este grupo
  merge() {
    this.moveAllTo(true)
    document.querySelector("#dest_existing").checked = true
    document.querySelector("#hide_source").checked = true
    document.querySelector("#target_id")?.focus()
  }

  moveAllTo(toGo) {
    const from = toGo ? this.stayTarget : this.goTarget
    ;[...from.children].filter(r => !r.hidden).forEach(r => this.send(r, toGo))
    this.refresh()
  }

  send(row, toGo) {
    ;(toGo ? this.goTarget : this.stayTarget).appendChild(row)
    row.querySelector("input[type=hidden]").disabled = !toGo
    row.querySelector("[data-arrow]").textContent = toGo ? "←" : "→"
  }

  filter() {
    const q = this.searchTarget.value.trim().toLowerCase()
    this.element.querySelectorAll("[data-row]").forEach(r => { r.hidden = q && !r.textContent.toLowerCase().includes(q) })
  }

  refresh() {
    this.stayCountTarget.textContent = this.stayTarget.children.length
    this.goCountTarget.textContent = this.goTarget.children.length
  }
}
