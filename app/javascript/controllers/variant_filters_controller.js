import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["search", "typeFilter", "statusFilter", "group"];

  filter() {
    const query = this.searchTarget.value.toLowerCase().trim();
    const typeId = this.typeFilterTarget.value;
    const status = this.statusFilterTarget.value;

    document.querySelectorAll("[data-variant-id]").forEach((row) => {
      const name = row.dataset.variantName || "";
      const rowType = row.dataset.typeId || "";
      const active = row.dataset.status || "";
      const hasRule = row.dataset.hasRule || "";

      const matchName = name.includes(query);
      const matchType = !typeId || rowType === typeId;
      const matchStatus =
        !status ||
        (status === "active" && active === "active") ||
        (status === "inactive" && active === "inactive") ||
        (status === "no_rule" && hasRule === "false");

      row.style.display = matchName && matchType && matchStatus ? "" : "none";
    });

    // Ocultar grupos vacíos
    this.groupTargets.forEach((group) => {
      const visible = group.querySelectorAll(
        "[data-variant-id]:not([style*='none'])",
      );
      group.style.display = visible.length > 0 ? "" : "none";
    });
  }
}
