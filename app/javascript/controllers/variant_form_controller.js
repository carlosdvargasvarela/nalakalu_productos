import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = [
    "displayName", // Nombre Comercial
    "code", // Código Corto
    "name", // Nombre Técnico
    "providerSku", // SKU Proveedor
    "nameWarning", // Badge de advertencia nombre
    "skuWarning", // Badge de advertencia SKU
  ];

  connect() {
    // Al cargar el form (modo edición), verificar si hay advertencias que mostrar
    this.checkNameWarning();
    this.checkSkuWarning();
  }

  // Se dispara cuando el usuario sale del campo Nombre Comercial
  syncName() {
    if (this.nameTarget.value.trim() === "") {
      this.nameTarget.value = this.displayNameTarget.value;
    }
    this.checkNameWarning();
  }

  // Se dispara cuando el usuario sale del campo Código Corto
  syncCode() {
    if (this.providerSkuTarget.value.trim() === "") {
      this.providerSkuTarget.value = this.codeTarget.value;
    }
    this.checkSkuWarning();
  }

  // Si el usuario edita manualmente el Nombre Técnico, ocultar advertencia
  onNameInput() {
    this.checkNameWarning();
  }

  // Si el usuario edita manualmente el SKU, ocultar advertencia
  onSkuInput() {
    this.checkSkuWarning();
  }

  checkNameWarning() {
    const commercial = this.displayNameTarget.value.trim();
    const technical = this.nameTarget.value.trim();

    if (commercial !== "" && (technical === "" || technical === commercial)) {
      this.nameWarningTarget.classList.remove("d-none");
    } else {
      this.nameWarningTarget.classList.add("d-none");
    }
  }

  checkSkuWarning() {
    const code = this.codeTarget.value.trim();
    const sku = this.providerSkuTarget.value.trim();

    if (code !== "" && (sku === "" || sku === code)) {
      this.skuWarningTarget.classList.remove("d-none");
    } else {
      this.skuWarningTarget.classList.add("d-none");
    }
  }
}
