import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = [
    "search",
    "provider",
    "mode",
    "status",
    "row",
    "visibleCount",
    "emptyState",
  ];

  connect() {
    this.filter();
  }

  filter() {
    const search = this.hasSearchTarget
      ? this.searchTarget.value.trim().toLowerCase()
      : "";
    const providerId = this.hasProviderTarget ? this.providerTarget.value : "";
    const mode = this.hasModeTarget ? this.modeTarget.value : "";
    const status = this.hasStatusTarget ? this.statusTarget.value : "";

    let visible = 0;

    this.rowTargets.forEach((row) => {
      const matchesSearch =
        !search || (row.dataset.name || "").includes(search);
      const matchesProvider =
        !providerId || row.dataset.providerId === providerId;
      const matchesMode = !mode || row.dataset.mode === mode;
      const matchesStatus = !status || row.dataset.status === status;

      const shouldShow =
        matchesSearch && matchesProvider && matchesMode && matchesStatus;
      row.hidden = !shouldShow;

      if (shouldShow) visible += 1;
    });

    if (this.hasVisibleCountTarget) {
      this.visibleCountTarget.textContent = visible;
    }

    if (this.hasEmptyStateTarget) {
      this.emptyStateTarget.hidden = visible > 0;
    }
  }

  reset() {
    if (this.hasSearchTarget) this.searchTarget.value = "";
    if (this.hasProviderTarget) this.providerTarget.value = "";
    if (this.hasModeTarget) this.modeTarget.value = "";
    if (this.hasStatusTarget) this.statusTarget.value = "";

    this.filter();
  }
}
