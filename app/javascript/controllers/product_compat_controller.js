import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["search", "item", "checkbox"];

  filter() {
    const q = this.searchTarget.value.toLowerCase().trim();
    this.itemTargets.forEach((item) => {
      item.style.display = item.dataset.name.includes(q) ? "" : "none";
    });
  }

  clear() {
    this.checkboxTargets.forEach((cb) => {
      cb.checked = false;
    });
  }
}
