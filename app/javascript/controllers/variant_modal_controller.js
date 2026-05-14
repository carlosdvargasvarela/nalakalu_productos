import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["modal", "formContainer"];

  connect() {
    if (!this.hasModalTarget) return;

    this.modal = bootstrap.Modal.getOrCreateInstance(this.modalTarget);

    this.modalTarget.addEventListener("hidden.bs.modal", () => this._cleanup());

    this.observer = new MutationObserver(() => {
      const signal = document.getElementById("variant-modal-signal");
      if (signal && signal.hasAttribute("data-variant-modal-target")) {
        this.close();
        signal.removeAttribute("data-variant-modal-target");
      }
    });

    this.observer.observe(this.modalTarget, { childList: true, subtree: true });
  }

  disconnect() {
    this.observer?.disconnect();
    this._cleanup();
  }

  async openNew(event) {
    event.preventDefault();
    this.resetForm();
    const url = event.currentTarget.href;
    await this.fetchForm(url);
    this.modal.show();
  }

  async openEdit(event) {
    event.preventDefault();
    this.resetForm();
    const url = event.currentTarget.href;
    await this.fetchForm(url);
    this.modal.show();
  }

  async fetchForm(url) {
    try {
      const response = await fetch(url, {
        headers: { Accept: "text/vnd.turbo-stream.html" },
      });
      const html = await response.text();
      Turbo.renderStreamMessage(html);
    } catch (error) {
      console.error("Error fetching form:", error);
    }
  }

  resetForm() {
    if (!this.hasFormContainerTarget) return;
    this.formContainerTarget.innerHTML = `
      <div class="text-center py-5">
        <div class="spinner-border text-info" role="status"></div>
      </div>`;
  }

  close() {
    this.modal?.hide();
  }

  _cleanup() {
    document.querySelectorAll(".modal-backdrop").forEach((el) => el.remove());
    document.body.classList.remove("modal-open");
    document.body.style.removeProperty("overflow");
    document.body.style.removeProperty("padding-right");
  }
}
