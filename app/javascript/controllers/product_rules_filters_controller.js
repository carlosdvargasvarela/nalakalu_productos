import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["search"];

  filter() {
    const query = this.searchTarget.value.toLowerCase();
    document.querySelectorAll(".product-rule-row").forEach((row) => {
      const name = row.dataset.productName || "";
      row.style.display = name.includes(query) ? "" : "none";
    });
  }
}
