import { Controller }    from "@hotwired/stimulus"
import { applyTomSelect } from "lib/search_selects"

export default class extends Controller {
  static targets = [
    "body", "row", "productSelect",
    "newProductName", "newProductCode", "newProductFamily", "quickCreateError"
  ]
  static values = { quickCreateUrl: String }

  connect() {
    this.#updateRemoveButtons()
    this._targetRowIndex = null
  }

  addRow(event) {
    event.preventDefault()
    const index    = this.rowTargets.length
    const template = this.rowTargets[0].cloneNode(true)

    // Extraer el <select> nativo de dentro del wrapper que crea TomSelect
    template.querySelectorAll(".ts-wrapper").forEach(wrapper => {
      const native = wrapper.querySelector("select")
      if (native) { native.removeAttribute("style"); wrapper.replaceWith(native) }
    })

    template.querySelectorAll("input, select, textarea").forEach(el => {
      el.name = el.name.replace(/items\[\d+\]/, `items[${index}]`)
      if (el.tagName === "SELECT") el.selectedIndex = 0
      else el.value = ""
    })

    this.bodyTarget.appendChild(template)
    applyTomSelect(template)
    this.#updateRemoveButtons()
  }

  removeRow(event) {
    event.preventDefault()
    if (this.rowTargets.length <= 1) return
    event.target.closest("[data-initial-stock-form-target='row']").remove()
    this.#reindex()
    this.#updateRemoveButtons()
  }

  openQuickCreate(event) {
    event.preventDefault()
    const row = event.target.closest("[data-initial-stock-form-target='row']")
    this._targetRowIndex = row ? this.rowTargets.indexOf(row) : null

    this.newProductNameTarget.value = ""
    this.newProductCodeTarget.value = ""
    if (this.hasNewProductFamilyTarget) this.newProductFamilyTarget.selectedIndex = 0
    this.quickCreateErrorTarget.textContent = ""
    this.quickCreateErrorTarget.classList.add("d-none")

    bootstrap.Modal.getOrCreateInstance(
      document.getElementById("quickCreateProductModal")
    ).show()
  }

  async submitQuickCreate(event) {
    event.preventDefault()
    const name = this.newProductNameTarget.value.trim()
    const code = this.newProductCodeTarget.value.trim()

    if (!name || !code) {
      this.#showQuickCreateError("Nombre y código son obligatorios.")
      return
    }

    const body = { product: { name, base_code: code } }
    if (this.hasNewProductFamilyTarget && this.newProductFamilyTarget.value) {
      body.product.family_id = this.newProductFamilyTarget.value
    }

    try {
      const resp = await fetch(this.quickCreateUrlValue, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "X-CSRF-Token": document.querySelector("meta[name='csrf-token']").content,
          "Accept": "application/json"
        },
        body: JSON.stringify(body)
      })
      const data = await resp.json()

      if (resp.ok) {
        // Insertar en todos los selects del doc en orden alfabético
        this.#distributeOption(data.id, data.name)
        // Auto-select en el row que abrió el modal
        if (this._targetRowIndex !== null) {
          const sel = this.rowTargets[this._targetRowIndex]
            ?.querySelector("[data-initial-stock-form-target='productSelect']")
          if (sel) {
            sel.tomselect ? sel.tomselect.setValue(String(data.id)) : (sel.value = data.id)
          }
        }
        bootstrap.Modal.getInstance(
          document.getElementById("quickCreateProductModal")
        ).hide()
      } else {
        this.#showQuickCreateError(data.error || "Error al crear el producto.")
      }
    } catch {
      this.#showQuickCreateError("Error de red. Intenta de nuevo.")
    }
  }

  #reindex() {
    this.rowTargets.forEach((row, i) => {
      row.querySelectorAll("input, select, textarea").forEach(el => {
        el.name = el.name.replace(/items\[\d+\]/, `items[${i}]`)
      })
    })
  }

  #updateRemoveButtons() {
    const single = this.rowTargets.length === 1
    this.rowTargets.forEach(row => {
      const btn = row.querySelector("[data-action*='removeRow']")
      if (btn) btn.disabled = single
    })
  }

  #distributeOption(id, name) {
    const strId = String(id)
    document.querySelectorAll("select[data-product-select]").forEach(sel => {
      if (!sel.querySelector(`option[value="${strId}"]`)) {
        const after = [...sel.options].find(o => o.value !== "" && o.text.localeCompare(name) > 0)
        const opt   = new Option(name, strId)
        after ? sel.insertBefore(opt, after) : sel.appendChild(opt)
      }
      if (sel.tomselect && !sel.tomselect.options[strId]) {
        sel.tomselect.addOption({ value: strId, text: name })
      }
    })
  }

  #showQuickCreateError(msg) {
    this.quickCreateErrorTarget.textContent = msg
    this.quickCreateErrorTarget.classList.remove("d-none")
  }
}
