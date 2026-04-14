import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["search", "family", "status", "list", "item"];

  filter() {
    const query = this.searchTarget.value.toLowerCase().trim();
    const family = this.familyTarget.value;
    const status = this.statusTarget.value;

    this.itemTargets.forEach((item) => {
      const name = item.dataset.name || "";
      const code = item.dataset.code || "";
      const itemFamily = item.dataset.family || "";
      const itemStatus = item.dataset.status || "";
      const procurement = item.dataset.procurement || "";
      const hasRules = item.dataset.hasRules === "true";

      const matchSearch =
        !query || name.includes(query) || code.includes(query);
      const matchFamily = !family || itemFamily === family;
      const matchStatus =
        !status ||
        (status === "active" && itemStatus === "active") ||
        (status === "inactive" && itemStatus === "inactive") ||
        (status === "ready" && procurement === "ready") ||
        (status === "incomplete" && procurement === "incomplete");

      item.style.display =
        matchSearch && matchFamily && matchStatus ? "" : "none";
    });
  }
}
