import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "productSelect",
    "variantsContainer",
    "result",
    "copyButton"
  ]

  static values = {
    url: String
  }

  connect() {
    this.baseCode = ""
    this.rules = []
    this.selections = {}
  }

  loadProduct() {
    const productId = this.productSelectTarget.value
    if (!productId) return

    fetch(`${this.urlValue}?product_id=${productId}`)
      .then(res => res.json())
      .then(data => {
        this.baseCode = data.base_code
        this.rules = data.rules
        this.selections = {}
        this.renderVariantSelectors()
        this.updateResult()
      })
  }

  renderVariantSelectors() {
    this.variantsContainerTarget.innerHTML = ""

    this.rules.forEach((rule, index) => {
      const wrapper = document.createElement("div")
      wrapper.classList.add("mb-3")

      wrapper.innerHTML = `
        <label class="form-label fw-bold">
          ${index + 2}️⃣ ${rule.variant_type_name}
          ${rule.required ? '<span class="text-danger">*</span>' : ''}
        </label>

        <select class="form-select"
                data-rule-id="${rule.rule_id}">
          <option value="">${rule.required ? "Seleccione..." : "Opcional"}</option>
          ${rule.variants.map(v =>
            `<option value="${v.id}" data-code="${v.code}">${v.name}</option>`
          ).join("")}
        </select>
      `

      wrapper.querySelector("select")
        .addEventListener("change", e => {
          this.selections[rule.rule_id] = e.target.selectedOptions[0]?.dataset.code || ""
          this.updateResult()
        })

      this.variantsContainerTarget.appendChild(wrapper)
    })
  }

  updateResult() {
    let code = this.baseCode
    let valid = true

    this.rules.forEach(rule => {
      const part = this.selections[rule.rule_id]

      if (rule.required && !part) {
        valid = false
      }

      if (part) {
        code += `${rule.separator}${part}`
      }
    })

    this.resultTarget.textContent = code || "—"
    this.copyButtonTarget.disabled = !valid
  }

  copy() {
    navigator.clipboard.writeText(this.resultTarget.textContent)
    this.copyButtonTarget.innerHTML = "✅ Copiado"
    setTimeout(() => {
      this.copyButtonTarget.innerHTML = `<i class="bi bi-clipboard"></i> Copiar Código`
    }, 1500)
  }
}