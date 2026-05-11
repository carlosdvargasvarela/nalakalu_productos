import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["typeSelect", "variantFields", "productFields", "variantTypeSelect", "variantNameInput", "existingVariants", "duplicateWarning"]
  static values = { checkUrl: String }

  connect() {
    this.toggle()
  }

  toggle() {
    const type = this.typeSelectTarget.value
    if (type === "new_variant") {
      this.variantFieldsTarget.classList.remove("d-none")
      this.productFieldsTarget.classList.add("d-none")
      this.loadExistingVariants()
    } else if (type === "new_product_variant_rule") {
      this.variantFieldsTarget.classList.add("d-none")
      this.productFieldsTarget.classList.remove("d-none")
      this.clearExistingVariants()
    } else {
      this.variantFieldsTarget.classList.add("d-none")
      this.productFieldsTarget.classList.add("d-none")
      this.clearExistingVariants()
    }
  }

  onVariantTypeChange() {
    this.toggle()
  }

  onNameInput() {
    this.checkDuplicate()
  }

  loadExistingVariants() {
    const vtId = this.variantTypeSelectTarget.value
    if (!vtId) return this.clearExistingVariants()

    const url = `/recommendations/check_existing?variant_type_id=${vtId}&name=${encodeURIComponent(this.variantNameInputTarget.value)}`
    fetch(url, { headers: { Accept: "application/json" } })
      .then(r => r.json())
      .then(data => {
        this.renderExistingVariants(data.variants)
        this.renderDuplicateWarning(data.exact_match)
      })
      .catch(() => {})
  }

  checkDuplicate() {
    if (this.typeSelectTarget.value !== "new_variant") return
    this.loadExistingVariants()
  }

  renderExistingVariants(variants) {
    if (!this.hasExistingVariantsTarget) return
    if (variants.length === 0) {
      this.existingVariantsTarget.innerHTML = ""
      return
    }
    const items = variants.map(v => `<span class="badge bg-light text-dark border me-1 mb-1">${v.name}</span>`).join("")
    this.existingVariantsTarget.innerHTML = `
      <div class="mt-2 p-2 bg-light rounded-3 border">
        <p class="text-muted small mb-1"><i class="bi bi-info-circle me-1"></i>Variantes que ya existen en este tipo:</p>
        <div>${items}</div>
      </div>`
  }

  renderDuplicateWarning(exactMatch) {
    if (!this.hasDuplicateWarningTarget) return
    if (exactMatch) {
      this.duplicateWarningTarget.classList.remove("d-none")
    } else {
      this.duplicateWarningTarget.classList.add("d-none")
    }
  }

  clearExistingVariants() {
    if (this.hasExistingVariantsTarget) this.existingVariantsTarget.innerHTML = ""
    if (this.hasDuplicateWarningTarget) this.duplicateWarningTarget.classList.add("d-none")
  }
}
