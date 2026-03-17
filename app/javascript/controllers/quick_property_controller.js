import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["modal", "status"];

  connect() {
    this.observer = new MutationObserver(() => this.checkStatus());
    if (this.hasStatusTarget) {
      this.observer.observe(this.statusTarget, {
        attributes: true,
        childList: true,
        subtree: true,
      });
    }
  }

  disconnect() {
    this.observer?.disconnect();
  }

  checkStatus() {
    const status = document.getElementById("quick-property-status");
    if (status?.dataset.saved === "true") {
      this.closeModal();
      status.removeAttribute("data-saved");
    }
  }

  openModal() {
    const modal = bootstrap.Modal.getOrCreateInstance(this.modalTarget);
    modal.show();
  }

  closeModal() {
    const modal = bootstrap.Modal.getInstance(this.modalTarget);
    modal?.hide();
  }
}
