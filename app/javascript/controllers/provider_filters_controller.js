import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["search", "categoryFilter", "statusFilter"];

  filter() {
    const query = this.searchTarget.value.toLowerCase().trim();
    const category = this.categoryFilterTarget.value;
    const status = this.statusFilterTarget.value;

    document.querySelectorAll("[data-provider-id]").forEach((row) => {
      const name = row.dataset.providerName || "";
      const rowCat = row.dataset.category || "";
      const rowStat = row.dataset.status || "";

      const matchName = name.includes(query);
      const matchCategory = !category || rowCat === category;
      const matchStatus =
        !status ||
        (status === "active" && rowStat === "active") ||
        (status === "inactive" && rowStat === "inactive");

      row.style.display =
        matchName && matchCategory && matchStatus ? "" : "none";
    });
  }
}
