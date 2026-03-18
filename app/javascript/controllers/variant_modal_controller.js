import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["modal", "formContainer"];

  connect() {
    // Inicializar el modal de Bootstrap
    this.modal = new bootstrap.Modal(this.modalTarget);

    // Escuchar la señal de cierre que viene desde Turbo Stream
    this.observer = new MutationObserver((mutations) => {
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
    this.formContainerTarget.innerHTML = `
      <div class="text-center py-5">
        <div class="spinner-border text-info" role="status"></div>
      </div>`;
  }

  close() {
    this.modal.hide();
    // Limpiar el backdrop de bootstrap si se queda pegado
    const backdrop = document.querySelector(".modal-backdrop");
    if (backdrop) backdrop.remove();
    document.body.classList.remove("modal-open");
    document.body.style.overflow = "";
    document.body.style.paddingRight = "";
  }
}
