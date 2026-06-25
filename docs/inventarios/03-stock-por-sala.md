# 🏪 Stock por sala

**Acceso:** Dashboard → clic en el nombre de una sala (encabezado de columna)\
**Ruta:** `/inventory/sala/:nombre-de-sala`

Vista detallada del inventario de una sala específica. Muestra todos los productos que tienen stock en esa sala y cuántas unidades hay de cada uno.

---

## Cómo llegar

Desde el [Dashboard](01-dashboard.md), hacé clic en el nombre de cualquier sala en el encabezado de la tabla de stock. El nombre es un enlace.

También podés llegar desde la [vista de Registrar salida](04-registrar-salida.md) si la sala ya está seleccionada.

---

## Qué ves al entrar

### Encabezado

```
← Inventario / Sala Norte

🏪 Sala Norte
   14 producto(s) · 87 unidades

              [ 📋 Ver movimientos ]  [ 📤 Registrar salida ]
```

* La **navegación** (miga de pan) te lleva de vuelta al Dashboard.
* El subtítulo muestra de un vistazo cuántos productos y unidades hay.
* Los botones de acceso rápido van directamente al historial de esa sala o al formulario de salida con la sala ya preseleccionada.

---

### Selector de sala

Una fila de botones con todas las salas disponibles. La sala activa aparece resaltada en azul. Haciendo clic en otra pasás a verla sin volver al Dashboard.

```
[ 🏪 Sala Norte ]  [ Sala Sur ]  [ Bodega Central ]  [ Showroom Premium ]
```

---

### Tabla de productos

Una fila por producto con la cantidad disponible en esa sala:

<table><thead><tr><th width="220">Columna</th><th>Qué muestra</th></tr></thead><tbody><tr><td><strong>Producto</strong></td><td>Nombre del producto</td></tr><tr><td><strong>Stock actual</strong></td><td>Unidades disponibles en esta sala</td></tr></tbody></table>

**Lectura de los valores:**

| Valor | Significado |
|-------|-------------|
| 🟢 Badge verde | Stock positivo — hay unidades disponibles |
| 🔴 Badge rojo | Stock negativo — probable error o salida no registrada |
| `0` | Sin stock, pero con historial de movimientos |

La última fila muestra el **total de unidades** en la sala.

---

### Buscador

El campo de búsqueda en el encabezado de la tabla filtra en tiempo real por nombre de producto. La **✕** limpia la búsqueda.

---

## Acciones disponibles desde esta pantalla

<table><thead><tr><th width="240">Acción</th><th>Cómo accederla</th></tr></thead><tbody><tr><td>Ver historial de la sala</td><td>Botón <kbd>Ver movimientos</kbd> en el encabezado</td></tr><tr><td>Registrar una salida de esta sala</td><td>Botón <kbd>Registrar salida</kbd> en el encabezado — abre el formulario con la sala ya elegida</td></tr><tr><td>Ver otra sala</td><td>Hacer clic en el nombre de otra sala en el selector</td></tr></tbody></table>

---

## Diferencia con el Dashboard

{% hint style="info" %}
**Dashboard** muestra todas las salas en horizontal (una columna por sala) — ideal para comparar.

**Stock por sala** muestra una sola sala en vertical — más cómodo en pantallas pequeñas o cuando querés enfocarte en una sala en particular.
{% endhint %}
