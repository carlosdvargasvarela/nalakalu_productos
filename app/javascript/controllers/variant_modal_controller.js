import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["modal", "formContainer"];

  connect() {
    this.modal = new bootstrap.Modal(this.modalTarget);

    // Observamos cambios en el modal para detectar la señal de cierre
    this.observer = new MutationObserver(() => {
      const signal = document.getElementById("variant-modal-signal");
      // Si el elemento existe y tiene el atributo de target (significa que fue reemplazado por Turbo)
      if (signal && signal.hasAttribute("data-variant-modal-target")) {
        this.close();
        // Limpiamos la señal para futuros usos
        signal.removeAttribute("data-variant-modal-target");
      }
    });

    this.observer.observe(this.modalTarget, { childList: true, subtree: true });
  }

  disconnect() {
    this.observer?.disconnect();
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
    const response = await fetch(url, {
      headers: { Accept: "text/vnd.turbo-stream.html" },
    });
    const html = await response.text();
    Turbo.renderStreamMessage(html);
  }

  resetForm() {
    this.formContainerTarget.innerHTML = `
      <div class="text-center py-5">
        <div class="spinner-border text-info" role="status"></div>
      </div>`;
  }

  close() {
    this.modal.hide();
  }
}
