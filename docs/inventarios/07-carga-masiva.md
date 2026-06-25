# 📁 Carga masiva por Excel

**Acceso:** Barra lateral → _Carga masiva_\
**Ruta:** `/inventory/bulk_imports/new`

Subí un archivo Excel con múltiples movimientos de inventario de una sola vez. Ideal cuando tenés una planilla externa con movimientos que necesitás reflejar en el sistema, o cuando un proveedor o equipo externo te entrega datos en formato Excel.

---

## Antes de subir: el formato del archivo

El archivo debe ser **`.xlsx`** (Excel moderno, no `.xls` ni `.csv`).

### Columnas requeridas

<table data-full-width="false"><thead><tr><th width="230">Columna</th><th width="130">Obligatoria</th><th>Descripción</th></tr></thead><tbody><tr><td><strong>Sala receptora</strong></td><td>Para entradas</td><td>Nombre exacto de la sala donde ingresa la mercancía</td></tr><tr><td><strong>Sala emisora</strong></td><td>Para salidas</td><td>Nombre exacto de la sala desde donde sale</td></tr><tr><td><strong>Código producto</strong></td><td>Sí</td><td>Código interno del producto en el sistema</td></tr><tr><td><strong>Nombre de producto</strong></td><td>Sí</td><td>Nombre del producto</td></tr><tr><td><strong>Cantidad</strong></td><td>Sí</td><td>Número de unidades (positivo)</td></tr><tr><td><strong>Pedido</strong></td><td>No</td><td>Número de pedido asociado</td></tr><tr><td><strong>Fecha del movimiento</strong></td><td>No</td><td>Si no se incluye, se usa la fecha de hoy</td></tr></tbody></table>

### Cómo completar según el tipo de movimiento

{% tabs %}
{% tab title="📦 Entrada" %}
Mercancía que **llega** a una sala.

| Campo | Valor |
|-------|-------|
| Sala receptora | ✅ Completar con la sala destino |
| Sala emisora | Dejar vacío |

El sistema crea un movimiento de **Entrada** en la sala receptora.
{% endtab %}

{% tab title="📤 Salida" %}
Mercancía que **sale** de una sala.

| Campo | Valor |
|-------|-------|
| Sala receptora | Dejar vacío |
| Sala emisora | ✅ Completar con la sala origen |

El sistema crea un movimiento de **Salida** en la sala emisora.
{% endtab %}

{% tab title="↔ Transferencia" %}
Mercancía que se **mueve de una sala a otra**.

| Campo | Valor |
|-------|-------|
| Sala receptora | ✅ Completar |
| Sala emisora | ✅ Completar |

El sistema crea dos movimientos: **Salida** en la sala emisora + **Entrada** en la sala receptora.
{% endtab %}
{% endtabs %}

{% hint style="info" %}
**Descargá la plantilla** haciendo clic en <kbd>⬇ Descargar plantilla</kbd> (parte superior derecha). Trae el formato correcto con ejemplos en cada columna — es el punto de partida más seguro.
{% endhint %}

---

## Paso a paso

1. Preparás tu archivo `.xlsx` usando la plantilla o el formato descrito arriba.
2. En la pantalla de Carga masiva, hacé clic en el campo de archivo y seleccioná tu archivo.
3. Hacé clic en <kbd>Procesar archivo</kbd>.

El sistema procesa el archivo y te lleva automáticamente a la pantalla de **[Revisión de sync](08-revision-sync.md)**, donde podés ver los movimientos detectados, corregir lo que sea necesario y confirmar.

{% hint style="success" %}
Los movimientos **no afectan el stock hasta que confirmás la carga** en la pantalla de revisión. Podés subir el mismo archivo varias veces sin problema — mientras no confirmés, no hay efecto real en el inventario.
{% endhint %}

---

## Filas con errores

Si el sistema no puede procesar alguna fila (cantidad no numérica, columnas inválidas, formato incorrecto), lo informa en la pantalla de revisión con un listado detallado:

```
⚠️ 2 fila(s) del archivo no se pudieron procesar y fueron omitidas:

   • Fila 5: cantidad no válida ("docena" no es un número)
   • Fila 12: sala receptora vacía y sala emisora vacía
```

Las filas con error se omiten. El resto del archivo se procesa normalmente — no es necesario subir el archivo de nuevo por un par de filas malas.

---

## Diferencia con Stock inicial y Ajuste

<table><thead><tr><th width="240">Herramienta</th><th>Cuándo usarla</th></tr></thead><tbody><tr><td><a href="07-carga-masiva.md">Carga masiva</a></td><td>Muchos movimientos de distintos tipos (entradas, salidas, transferencias) desde un Excel externo</td></tr><tr><td><a href="05-stock-inicial.md">Stock inicial</a></td><td>Primer inventario de una sala, producto por producto en la interfaz</td></tr><tr><td><a href="06-ajuste.md">Ajustar inventario</a></td><td>Corrección puntual de cantidades tras un conteo físico</td></tr></tbody></table>
