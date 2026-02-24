import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = [
    "selectAll",
    "checkbox",
    "count",
    "submitBtn",
    "row",
    "search",
  ];

  connect() {
    this.updateUI();
  }

  toggleAll() {
    const checked = this.selectAllTarget.checked;
    this.checkboxTargets.forEach((cb) => {
      if (cb.closest("tr").style.display !== "none") {
        cb.checked = checked;
      }
    });
    this.updateUI();
  }

  updateUI() {
    const count = this.checkboxTargets.filter((cb) => cb.checked).length;
    this.countTarget.textContent = count;
    this.submitBtnTarget.disabled = count === 0;
  }

  filter() {
    const term = this.searchTarget.value.toLowerCase();
    this.rowTargets.forEach((row) => {
      row.style.display = row.textContent.toLowerCase().includes(term)
        ? ""
        : "none";
    });
    // Desmarcamos "seleccionar todos" al filtrar para evitar confusiones
    this.selectAllTarget.checked = false;
  }
}
