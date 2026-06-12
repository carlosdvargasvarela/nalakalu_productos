import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["productSelect", "newProductName", "newProductCode", "newProductFamily", "quickCreateError"]
  static values = { quickCreateUrl: String }

  connect() {
    this._targetSelect = null
  }

  openQuickCreate(event) {
    event.preventDefault()
    const row = event.target.closest("tr")
    this._targetSelect = row
      ? row.querySelector("[data-sync-review-target='productSelect']")
      : null

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
        this.productSelectTargets.forEach(sel => {
          sel.appendChild(new Option(data.name, data.id))
        })
        if (this._targetSelect) {
          this._targetSelect.value = data.id
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

  #showQuickCreateError(msg) {
    this.quickCreateErrorTarget.textContent = msg
    this.quickCreateErrorTarget.classList.remove("d-none")
  }
}
