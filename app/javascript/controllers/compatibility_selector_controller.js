import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["input", "list", "item"];

  filter(event) {
    const query = event.target.value.toLowerCase();
    this.itemTargets.forEach((item) => {
      const text = item.dataset.searchText.toLowerCase();
      item.classList.toggle("d-none", !text.includes(query));
    });
  }

  toggleAll(event) {
    const checked = event.target.checked;
    this.itemTargets.forEach((item) => {
      if (!item.classList.contains("d-none")) {
        const checkbox = item.querySelector('input[type="checkbox"]');
        checkbox.checked = checked;
      }
    });
  }
}
