import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["selectAll", "check", "hiddenContainer", "submitBtn"];
  static values = { providerId: String };

  toggleAll(event) {
    const checked = event.target.checked;
    this.checkTargets.forEach((c) => (c.checked = checked));
    this.updateHiddenInputs();
  }

  toggleOne() {
    const allChecked = this.checkTargets.every((c) => c.checked);
    this.selectAllTarget.checked = allChecked;
    this.updateHiddenInputs();
  }

  updateHiddenInputs() {
    this.hiddenContainerTarget.innerHTML = "";

    this.checkTargets
      .filter((c) => c.checked)
      .flatMap((c) => c.value.split(","))
      .forEach((id) => {
        const input = document.createElement("input");
        input.type = "hidden";
        input.name = "requirement_ids[]";
        input.value = id;
        this.hiddenContainerTarget.appendChild(input);
      });

    // Deshabilitar botón si no hay selección
    const hasSelection = this.checkTargets.some((c) => c.checked);
    this.submitBtnTarget.disabled = !hasSelection;
  }
}
