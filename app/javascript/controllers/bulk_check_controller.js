import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["selectAll", "checkbox", "bulkButton", "countBadge"]

  connect() {
    this.updateBulkButton()
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

    if (this.hasBulkButtonTarget) {
      this.bulkButtonTarget.disabled = count === 0
    }
    if (this.hasCountBadgeTarget) {
      this.countBadgeTarget.textContent = count > 0 ? `(${count})` : ""
    }
    if (this.hasSelectAllTarget) {
      this.selectAllTarget.checked = count === total && total > 0
      this.selectAllTarget.indeterminate = count > 0 && count < total
    }
  }
}
