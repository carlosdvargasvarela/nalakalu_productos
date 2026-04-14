import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["search"];

  filter() {
    const query = this.searchTarget.value.toLowerCase().trim();
    document.querySelectorAll("#vt-list [data-vt-name]").forEach((row) => {
      const name = row.dataset.vtName || "";
      row.style.display = name.includes(query) ? "" : "none";
    });
  }
}
