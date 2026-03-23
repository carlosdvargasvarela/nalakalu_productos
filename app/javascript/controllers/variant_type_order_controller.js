import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["list", "status", "error"];
  static values = { updateUrl: String };

  connect() {
    if (typeof Sortable === "undefined") {
      console.warn("SortableJS no está cargado.");
      return;
    }

    this.sortable = new Sortable(this.listTarget, {
      animation: 150,
      ghostClass: "table-active",
      handle: ".bi-grip-vertical",
      onEnd: () => this.saveOrder(),
    });
  }

  disconnect() {
    this.sortable?.destroy();
  }

  saveOrder() {
    const order = Array.from(this.listTarget.children).map(
      (el) => el.dataset.id,
    );

    fetch(this.updateUrlValue, {
      method: "PATCH",
      headers: {
        "Content-Type": "application/json",
        "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]')
          ?.content,
      },
      body: JSON.stringify({ order }),
    })
      .then((res) => {
        if (!res.ok) throw new Error("Error del servidor");
        this.showStatus("status");
        this.updateBadges();
      })
      .catch(() => this.showStatus("error"));
  }

  // Actualiza los badges #1, #2... sin recargar la página
  updateBadges() {
    Array.from(this.listTarget.children).forEach((el, index) => {
      const badge = el.querySelector(".badge.bg-secondary");
      if (badge) badge.textContent = `#${index + 1}`;
    });
  }

  showStatus(target) {
    const el = this[`${target}Target`];
    el.classList.remove("d-none");
    setTimeout(() => el.classList.add("d-none"), 2500);
  }
}
