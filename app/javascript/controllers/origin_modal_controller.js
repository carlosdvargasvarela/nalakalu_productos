import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["modal"];

  connect() {
    if (!this.hasModalTarget) return;

    this.bsModal = bootstrap.Modal.getOrCreateInstance(this.modalTarget);

    this.modalTarget.addEventListener("hidden.bs.modal", () => {
      this._cleanup();
    });
  }

  open(event) {
    event.preventDefault();
    const url = event.currentTarget.dataset.url;
    if (!url) return;

    // Si bsModal no existe aún (modal fuera de scope), buscarlo por ID
    if (!this.bsModal) {
      const el = document.getElementById("originOrderModal");
      if (!el) return;
      this.bsModal = bootstrap.Modal.getOrCreateInstance(el);

      el.addEventListener("hidden.bs.modal", () => this._cleanup(), {
        once: false,
      });
    }

    const container = document.getElementById("origin_order_modal_body");
    if (!container) return;

    container.innerHTML = `
      <div class="modal-body text-center py-5 text-muted">
        <div class="spinner-border spinner-border-sm me-2"></div>
        Cargando desglose...
      </div>
    `;

    this.bsModal.show();

    fetch(url, {
      headers: { Accept: "text/html", "X-Requested-With": "XMLHttpRequest" },
    })
      .then((r) => r.text())
      .then((html) => {
        const c = document.getElementById("origin_order_modal_body");
        if (c) c.innerHTML = html;
      })
      .catch(() => {
        const c = document.getElementById("origin_order_modal_body");
        if (c)
          c.innerHTML = `
            <div class="modal-body text-center py-4 text-danger">
              <i class="bi bi-exclamation-triangle-fill me-2"></i>
              Error al cargar el desglose.
            </div>
          `;
      });
  }

  close() {
    this.bsModal?.hide();
  }

  _cleanup() {
    document.querySelectorAll(".modal-backdrop").forEach((el) => el.remove());
    document.body.classList.remove("modal-open");
    document.body.style.removeProperty("overflow");
    document.body.style.removeProperty("padding-right");
  }

  disconnect() {
    this._cleanup();
  }
}
