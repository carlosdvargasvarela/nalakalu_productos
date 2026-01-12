import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["template", "target"];
  static values = { wrapperSelector: String };

  add(e) {
    e.preventDefault();
    const content = this.templateTarget.innerHTML.replace(
      /NEW_RECORD/g,
      new Date().getTime().toString()
    );
    this.targetTarget.insertAdjacentHTML("beforebegin", content);
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
    // Actualiza automáticamente el campo position basado en el orden visual
    this.element
      .querySelectorAll(this.wrapperSelectorValue)
      .forEach((wrapper, index) => {
        const positionInput = wrapper.querySelector(
          "input[data-role='position']"
        );
        if (positionInput) positionInput.value = index + 1;
      });
  }
}
