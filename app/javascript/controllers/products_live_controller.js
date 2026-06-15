import { Controller } from "@hotwired/stimulus"

// Distribuye productos creados en tiempo real a todos los <select data-product-select>
// del documento. El broadcast Turbo Stream aterriza en #products_live_source (oculto),
// el MutationObserver lo detecta y copia la opción a todos los selects visibles,
// respetando el orden alfabético y evitando duplicados.
export default class extends Controller {
  static targets = ["source"]

  connect() {
    if (!this.hasSourceTarget) return
    this._observer = new MutationObserver(mutations => {
      mutations.forEach(({ addedNodes }) => {
        addedNodes.forEach(node => {
          if (node.nodeType === Node.ELEMENT_NODE && node.tagName === "OPTION") {
            this.#distribute(node)
          }
        })
      })
    })
    this._observer.observe(this.sourceTarget, { childList: true })
  }

  disconnect() {
    this._observer?.disconnect()
  }

  #distribute(option) {
    document.querySelectorAll("select[data-product-select]").forEach(sel => {
      if (sel.querySelector(`option[value="${option.value}"]`)) return

      const clone = option.cloneNode(true)
      const insertBefore = [...sel.options].find(
        o => o.value !== "" && o.text.localeCompare(clone.text) > 0
      )
      insertBefore ? sel.insertBefore(clone, insertBefore) : sel.appendChild(clone)
    })
  }
}
