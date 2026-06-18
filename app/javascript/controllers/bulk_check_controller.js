import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["selectAll", "checkbox", "bulkButton", "countBadge", "form"]

  connect() {
    this.updateBulkButton()
    this._fillIds = this.fillIds.bind(this)
    this.formTargets.forEach(form => form.addEventListener("submit", this._fillIds))
  }

  disconnect() {
    this.formTargets.forEach(form => form.removeEventListener("submit", this._fillIds))
  }

  toggleAll() {
    const checked = this.selectAllTarget.checked
    this.checkboxTargets.forEach(cb => cb.checked = checked)
    this.updateBulkButton()
  }

  updateBulkButton() {
    const checked = this.checkboxTargets.filter(cb => cb.checked)
    const count = checked.length
    const total = this.checkboxTargets.length

    this.bulkButtonTargets.forEach(btn => btn.disabled = count === 0)
    if (this.hasCountBadgeTarget) {
      this.countBadgeTarget.textContent = count > 0 ? `(${count})` : ""
    }
    if (this.hasSelectAllTarget) {
      this.selectAllTarget.checked = count === total && total > 0
      this.selectAllTarget.indeterminate = count > 0 && count < total
    }
  }

  selectedIds() {
    return this.checkboxTargets.filter(cb => cb.checked).map(cb => cb.value)
  }

  fillIds(event) {
    const form = event.target
    form.querySelectorAll("input[data-bulk-check-id]").forEach(el => el.remove())
    this.selectedIds().forEach(id => {
      const input = document.createElement("input")
      input.type = "hidden"
      input.name = "ids[]"
      input.value = id
      input.dataset.bulkCheckId = "true"
      form.appendChild(input)
    })
  }
}
