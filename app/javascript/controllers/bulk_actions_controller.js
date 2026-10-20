import { Controller } from "@hotwired/stimulus"

// Selección en masa en las listas. Las casillas de cada fila envían su id con el formulario #bulk-form (atributo form=).
// «Seleccionar los N resultados» recoge los ids de todo el filtro (no solo de la página visible).
export default class extends Controller {
  static targets = ["all", "row", "bar", "count", "everyone", "allMode", "allIds"]
  static values = { allIds: Array }

  connect() { this.update() }

  toggleAll() {
    this.rowTargets.forEach(box => { box.checked = this.allTarget.checked })
    this.allModeTarget.value = "0"
    this.update()
  }

  rowChanged() {
    this.allModeTarget.value = "0"
    this.update()
  }

  selectEveryone(event) {
    event.preventDefault()
    this.allModeTarget.value = "1"
    this.allIdsTarget.value = this.allIdsValue.join(",")
    this.update()
  }

  clear(event) {
    event?.preventDefault()
    this.rowTargets.forEach(box => { box.checked = false })
    this.allTarget.checked = false
    this.allModeTarget.value = "0"
    this.update()
  }

  // El formulario va sin Turbo (muestra páginas completas), así que la confirmación es el confirm del navegador
  confirm(event) {
    if (!window.confirm(event.params.message)) event.preventDefault()
  }

  update() {
    const allMode = this.allModeTarget.value === "1"
    const checked = this.rowTargets.filter(box => box.checked).length
    const total = this.allIdsValue.length
    const n = allMode ? total : checked

    this.barTarget.classList.toggle("d-none", n === 0)
    this.countTarget.textContent = n === 1 ? "1 seleccionado" : `${n} seleccionados`
    this.allTarget.checked = checked > 0 && checked === this.rowTargets.length
    this.allTarget.indeterminate = checked > 0 && checked < this.rowTargets.length
    // ofrecer "todos los resultados" cuando se marcó toda la página y hay más resultados que casillas
    const offer = !allMode && checked === this.rowTargets.length && total > checked
    this.everyoneTarget.classList.toggle("d-none", !offer)
    this.everyoneTarget.textContent = `Seleccionar los ${total} resultados`
  }
}
