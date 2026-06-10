import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["body", "row", "orderInput", "showroomSelect"]
  static values  = { newUrl: String }

  connect() {
    this.#updateRemoveButtons()
  }

  addRow(event) {
    event.preventDefault()
    const index    = this.rowTargets.length
    const template = this.rowTargets[0].cloneNode(true)

    template.querySelectorAll("input, select, textarea").forEach(el => {
      el.name = el.name.replace(/items\[\d+\]/, `items[${index}]`)
      if (el.tagName === "SELECT") {
        el.selectedIndex = 0
      } else {
        el.value = ""
      }
    })

    this.bodyTarget.appendChild(template)
    this.#updateRemoveButtons()
  }

  removeRow(event) {
    event.preventDefault()
    if (this.rowTargets.length <= 1) return
    event.target.closest("[data-inventory-exit-form-target='row']").remove()
    this.#reindex()
    this.#updateRemoveButtons()
  }

  consultOrder(event) {
    event.preventDefault()
    const orderNumber = this.hasOrderInputTarget ? this.orderInputTarget.value : ""
    const showroomId  = this.hasShowroomSelectTarget ? this.showroomSelectTarget.value : ""
    const base        = new URL(this.newUrlValue, window.location.origin)
    if (orderNumber) base.searchParams.set("order_number", orderNumber)
    if (showroomId)  base.searchParams.set("showroom_id", showroomId)
    window.location.href = base.toString()
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
}
