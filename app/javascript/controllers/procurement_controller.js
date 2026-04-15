// app/javascript/controllers/procurement_controller.js
import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = [
    "check",
    "selectAll",
    "hiddenContainer",
    "submitBtn",
    "modalBody",
    "priceInput",
    "grandTotal",
  ];

  static values = {
    providerId: Number,
  };

  connect() {
    this.updateTotals();
    this.updateSubmitState();
  }

  // ── Selección ──────────────────────────────────────────────────────────────

  toggleAll(e) {
    this.checkTargets.forEach((cb) => (cb.checked = e.target.checked));
    this.updateTotals();
    this.updateSubmitState();
  }

  toggleOne() {
    const allChecked = this.checkTargets.every((cb) => cb.checked);
    if (this.hasSelectAllTarget) {
      this.selectAllTarget.checked = allChecked;
      this.selectAllTarget.indeterminate =
        !allChecked && this.checkTargets.some((cb) => cb.checked);
    }
    this.updateTotals();
    this.updateSubmitState();
  }

  // ── Precios y totales ──────────────────────────────────────────────────────

  updatePrice(e) {
    const row = e.target.closest("tr");
    const qty = parseFloat(row.dataset.quantity || 0);
    const price = this.parsePrice(e.target.value);
    const lineTotal = qty * price;

    const totalEl = row.querySelector("[data-line-total]");
    if (totalEl) totalEl.textContent = this.formatCRC(lineTotal);

    this.updateTotals();
  }

  updateTotals() {
    let grand = 0;

    this.checkTargets.forEach((cb) => {
      const row = cb.closest("tr");
      if (!row) return;

      const qty = parseFloat(row.dataset.quantity || 0);
      const priceInput = row.querySelector("[data-price-input]");
      const price = priceInput ? this.parsePrice(priceInput.value) : 0;
      const lineTotal = qty * price;

      const totalEl = row.querySelector("[data-line-total]");
      if (totalEl) totalEl.textContent = this.formatCRC(lineTotal);

      if (cb.checked) grand += lineTotal;
    });

    if (this.hasGrandTotalTarget) {
      this.grandTotalTarget.textContent = this.formatCRC(grand);
    }
  }

  updateSubmitState() {
    const anyChecked = this.checkTargets.some((cb) => cb.checked);
    if (this.hasSubmitBtnTarget) {
      this.submitBtnTarget.disabled = !anyChecked;
    }
  }

  // ── Modal de confirmación ──────────────────────────────────────────────────

  openConfirmModal() {
    const rows = this.checkTargets
      .filter((cb) => cb.checked)
      .map((cb) => cb.closest("tr"));

    if (!rows.length) return;

    let tableRows = "";
    let grandTotal = 0;

    rows.forEach((row) => {
      const name =
        row.querySelector("[data-item-name]")?.textContent?.trim() || "—";
      const sku =
        row.querySelector("[data-item-sku]")?.textContent?.trim() || "";
      const qty = parseFloat(row.dataset.quantity || 0);
      const unit =
        row.querySelector("[data-item-unit]")?.textContent?.trim() || "";
      const priceInput = row.querySelector("[data-price-input]");
      const price = priceInput ? this.parsePrice(priceInput.value) : 0;
      const lineTotal = qty * price;
      grandTotal += lineTotal;

      const specEls = row.querySelectorAll("[data-item-spec]");
      const specsHtml = specEls.length
        ? Array.from(specEls)
            .map(
              (s) =>
                `<span style="display:inline-block;font-size:11px;padding:2px 8px;border-radius:20px;background:#dbeafe;color:#1d4ed8;margin:2px;">${s.textContent.trim()}</span>`,
            )
            .join("")
        : '<span style="color:#94a3b8;font-size:12px;">—</span>';

      const originEls = row.querySelectorAll("[data-origin-product]");
      const originsHtml = originEls.length
        ? `<div style="margin-top:4px;">${Array.from(originEls)
            .map(
              (o) =>
                `<span style="display:inline-block;font-size:11px;padding:2px 7px;border-radius:4px;background:#f1f5f9;color:#475569;margin:2px;">${o.textContent.trim()}</span>`,
            )
            .join("")}</div>`
        : "";

      tableRows += `
        <tr style="border-bottom: 0.5px solid #e2e8f0;">
          <td style="padding: 10px 8px; vertical-align: top;">
            <div style="font-weight: 500; font-size: 13px;">${name}</div>
            <div style="font-size: 11px; color: #94a3b8; font-family: monospace;">${sku}</div>
            <div style="margin-top: 4px;">${specsHtml}</div>
            ${originsHtml}
          </td>
          <td style="padding: 10px 8px; text-align: center; white-space: nowrap; font-size: 13px;">
            <strong>${qty}</strong> <span style="color:#94a3b8;">${unit}</span>
          </td>
          <td style="padding: 10px 8px; text-align: right; font-size: 13px; white-space: nowrap;">
            ${this.formatCRC(price)}
          </td>
          <td style="padding: 10px 8px; text-align: right; font-size: 13px; font-weight: 500; white-space: nowrap;">
            ${this.formatCRC(lineTotal)}
          </td>
        </tr>
      `;
    });

    this.modalBodyTarget.innerHTML = `
      <table style="width:100%; border-collapse: collapse; font-size: 13px;">
        <thead>
          <tr style="border-bottom: 1px solid #cbd5e1;">
            <th style="text-align:left; padding: 6px 8px; color: #64748b; font-weight: 500;">Descripción</th>
            <th style="text-align:center; padding: 6px 8px; color: #64748b; font-weight: 500;">Cant.</th>
            <th style="text-align:right; padding: 6px 8px; color: #64748b; font-weight: 500;">Precio unit.</th>
            <th style="text-align:right; padding: 6px 8px; color: #64748b; font-weight: 500;">Total</th>
          </tr>
        </thead>
        <tbody>${tableRows}</tbody>
        <tfoot>
          <tr>
            <td colspan="3" style="text-align:right; padding: 10px 8px; font-weight: 500; color: #64748b; border-top: 1px solid #cbd5e1;">Total OC</td>
            <td style="text-align:right; padding: 10px 8px; font-size: 15px; font-weight: 600; border-top: 1px solid #cbd5e1;">${this.formatCRC(grandTotal)}</td>
          </tr>
        </tfoot>
      </table>
    `;

    this.syncHiddenPrices(rows);

    const modal = new bootstrap.Modal(
      document.getElementById(`confirmModal-${this.providerIdValue}`),
    );
    modal.show();
  }

  confirmSubmit() {
    const checkedBoxes = this.checkTargets.filter((cb) => cb.checked);
    const ids = checkedBoxes.flatMap((cb) => cb.value.split(","));

    // Limpiar hidden inputs anteriores
    this.hiddenContainerTarget.innerHTML = ids
      .map(
        (id) => `<input type="hidden" name="requirement_ids[]" value="${id}">`,
      )
      .join("");

    // Sincronizar precios
    const rows = checkedBoxes.map((cb) => cb.closest("tr"));
    this.syncHiddenPrices(rows);

    // Cerrar modal y submitear
    const modalEl = document.getElementById(
      `confirmModal-${this.providerIdValue}`,
    );
    bootstrap.Modal.getInstance(modalEl)?.hide();

    this.hiddenContainerTarget.closest("form").submit();
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  syncHiddenPrices(rows) {
    // Remover precios anteriores
    this.hiddenContainerTarget
      .querySelectorAll("[data-price-hidden]")
      .forEach((el) => el.remove());

    rows.forEach((row) => {
      const priceInput = row.querySelector("[data-price-input]");
      const reqIds =
        row.querySelector("input[type=checkbox]")?.value?.split(",") || [];
      if (!priceInput || !reqIds.length) return;

      const price = this.parsePrice(priceInput.value);
      reqIds.forEach((id) => {
        const hidden = document.createElement("input");
        hidden.type = "hidden";
        hidden.name = `unit_costs[${id}]`;
        hidden.value = price;
        hidden.dataset.priceHidden = "true";
        this.hiddenContainerTarget.appendChild(hidden);
      });
    });
  }

  parsePrice(val) {
    if (!val) return 0;
    return parseFloat(String(val).replace(/\./g, "").replace(",", ".")) || 0;
  }

  formatCRC(amount) {
    return (
      "₡" +
      amount.toLocaleString("es-CR", {
        minimumFractionDigits: 2,
        maximumFractionDigits: 2,
      })
    );
  }
}
