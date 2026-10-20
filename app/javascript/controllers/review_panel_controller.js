import { Controller } from "@hotwired/stimulus"

// Panel de revisión: motivos rápidos y atajos de teclado (A aprobar, C pedir cambios, S saltar, P anterior, E editar).
export default class extends Controller {
  static targets = ["note", "approve", "changes", "skip", "prev", "edit"]

  connect() {
    this.onKey = this.onKey.bind(this)
    document.addEventListener("keydown", this.onKey)
  }

  disconnect() { document.removeEventListener("keydown", this.onKey) }

  reason({ params: { text } }) {
    const note = this.noteTarget
    note.value = note.value.trim() ? `${note.value.trim().replace(/[.;]$/, "")}; ${text}` : text
    note.focus()
  }

  onKey(event) {
    if (event.ctrlKey || event.metaKey || event.altKey) return
    if (event.target.closest?.("input, textarea, select, [contenteditable]")) return
    const actions = {
      a: () => this.approveTarget.click(),
      c: () => { this.noteTarget.focus(); event.preventDefault() },
      s: () => this.skipTarget.click(),
      p: () => this.prevTarget.click(),
      e: () => this.editTarget.click()
    }
    const action = actions[event.key.toLowerCase()]
    if (action) action()
  }
}
