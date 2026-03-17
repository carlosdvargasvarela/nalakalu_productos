import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["template", "target"];
  static values = { wrapperSelector: String };

  add(e) {
    e.preventDefault();
    const content = this.templateTarget.innerHTML.replace(
      /NEW_RECORD/g,
      new Date().getTime().toString(),
    );
    // Insertar DENTRO del target, no antes de él
    this.targetTarget.insertAdjacentHTML("beforeend", content);
    this.updatePositions();
  }

  remove(e) {
    e.preventDefault();
    const wrapper = e.target.closest(this.wrapperSelectorValue);
    if (wrapper.dataset.newRecord === "true") {
      wrapper.remove();
    } else {
      wrapper.querySelector("input[name*='_destroy']").value = "1";
      wrapper.style.display = "none";
    }
    this.updatePositions();
  }

  updatePositions() {
    // Buscar dentro del targetTarget, ignorar los ocultos (_destroy=1)
    this.targetTarget
      .querySelectorAll(this.wrapperSelectorValue)
      .forEach((wrapper, index) => {
        if (wrapper.style.display === "none") return;
        const positionInput = wrapper.querySelector(
          "input[data-role='position']",
        );
        if (positionInput) positionInput.value = index + 1;
      });
  }
}
