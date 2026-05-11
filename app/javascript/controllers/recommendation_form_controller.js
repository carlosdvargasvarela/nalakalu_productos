import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["typeSelect", "variantFields", "productFields"]

  connect() {
    this.toggle()
  }

  toggle() {
    const type = this.typeSelectTarget.value
    if (type === "new_variant") {
      this.variantFieldsTarget.classList.remove("d-none")
      this.productFieldsTarget.classList.add("d-none")
    } else if (type === "new_product_variant_rule") {
      this.variantFieldsTarget.classList.add("d-none")
      this.productFieldsTarget.classList.remove("d-none")
    } else {
      this.variantFieldsTarget.classList.add("d-none")
      this.productFieldsTarget.classList.add("d-none")
    }
  }
}
