# 📊 Dashboard — Stock de inventario

**Acceso:** Barra lateral → _Dashboard_\
**Ruta:** `/inventory`

La pantalla principal del módulo. De un vistazo sabés cuántas unidades tiene cada producto en cada sala y si hay situaciones que requieren atención inmediata.

---

## Tarjetas de resumen

Al entrar, lo primero que ves son cuatro tarjetas en la parte superior:

{% tabs %}
{% tab title="📦 Productos en stock" %}
Muestra cuántos productos distintos tienen al menos una unidad registrada.

Si algunos productos tienen stock en cero, aparece debajo del número en **rojo**: _"X sin stock"_.

Hacé clic en el filtro **Sin stock** en la tabla para verlos rápidamente.
{% endtab %}

{% tab title="📚 Unidades totales" %}
La suma de todas las unidades en todas las salas y todos los productos.

Este número refleja únicamente movimientos **confirmados** — los syncs pendientes no están incluidos.
{% endtab %}

{% tab title="🔄 Syncs pendientes" %}
Cuántas sincronizaciones esperan ser revisadas y aplicadas al stock.

* Si el número es **0** → la tarjeta está en gris, todo está al día.
* Si es **mayor que 0** → la tarjeta se resalta en **amarillo** y podés hacer clic para ir directo a revisarla.

{% hint style="warning" %}
Mientras haya syncs pendientes, el stock mostrado en el Dashboard puede estar incompleto. Revisalos primero antes de tomar decisiones basadas en el stock.
{% endhint %}
{% endtab %}

{% tab title="⚠️ Alertas activas" %}
Discrepancias detectadas cuando se registró una salida con stock insuficiente.

* Si el número es **0** → la tarjeta está en gris, sin problemas.
* Si es **mayor que 0** → la tarjeta se resalta en **rojo** y hacés clic para ir a [Alertas](09-alertas.md).
{% endtab %}
{% endtabs %}

---

## Aviso de syncs pendientes

Cuando hay sincronizaciones sin confirmar, aparece un bloque de advertencia amarillo debajo de las tarjetas con un botón por cada sync pendiente.

```
⚠️  2 sincronización(es) pendiente(s) — el stock mostrado no incluye
    estos movimientos hasta que sean confirmados.

    [ Revisar 01/06–15/06  3 ]    [ Revisar 16/06–30/06  7 ]
```

El número en el badge de cada botón indica cuántos ítems tiene ese sync sin resolver. Hacé clic en el que quieras revisar primero.

---

## Tabla de stock por sala

La sección principal muestra una tabla con **una fila por producto** y **una columna por sala**, más una columna **Total** al final.

### Leer la tabla

<table><thead><tr><th width="180">Lo que ves</th><th>Qué significa</th></tr></thead><tbody><tr><td><span data-gb-custom-inline data-tag="emoji" data-code="1f7e2">🟢</span> Badge verde</td><td>Stock positivo en esa sala</td></tr><tr><td><span data-gb-custom-inline data-tag="emoji" data-code="1f534">🔴</span> Badge rojo</td><td>Stock negativo — posible error de datos o salida sin entrada registrada</td></tr><tr><td>—</td><td>Sin movimientos registrados para ese producto en esa sala</td></tr><tr><td>Fila inferior</td><td>Total de unidades por sala</td></tr></tbody></table>

### Interacciones

**Nombre del producto →** Abre un panel con el historial completo de ese producto: todas sus entradas, salidas y ajustes, ordenados por fecha.

**Nombre de la sala (encabezado de columna) →** Lleva a la [vista detallada de esa sala](03-stock-por-sala.md) con todos sus productos.

---

## Filtros de la tabla

La barra de búsqueda y filtros aparece en el encabezado de la tabla cuando hay productos:

<table><thead><tr><th width="200">Control</th><th>Qué hace</th></tr></thead><tbody><tr><td>🔍 Campo de búsqueda</td><td>Filtra filas por nombre de producto en tiempo real, sin recargar la página</td></tr><tr><td>Botón <strong>X</strong></td><td>Limpia la búsqueda y muestra todos los productos</td></tr><tr><td>Botón <strong>Sin stock (N)</strong></td><td>Aparece solo si hay productos en cero. Alterna entre "todos" y "solo los sin stock"</td></tr></tbody></table>

---

## Acciones del encabezado

### Exportar

<kbd>Exportar</kbd> descarga un archivo **CSV** con todos los productos y su stock actual desglosado por sala. Útil para reportes o para compartir información con otras áreas sin darles acceso al sistema.

### Sincronizar

<kbd>Sincronizar</kbd> lanza una importación manual desde el sistema logístico para el rango de fechas predefinido.

{% hint style="info" %}
La sincronización **no modifica el stock de inmediato**. Genera un borrador que revisás y confirmás en la pantalla de [Revisión de sync](08-revision-sync.md).
{% endhint %}

<details>

<summary>¿Querés cambiar el rango de fechas antes de sincronizar?</summary>

Hacé clic en el ícono de calendario 📅 que está al lado del botón Sincronizar. Se despliega un formulario con dos campos:

* **Desde** — fecha de inicio del rango
* **Hasta** — fecha de fin del rango

Completá las fechas y hacé clic en <kbd>Iniciar sync</kbd>.

Los valores por defecto de este rango se configuran en [Configuración de sync → Defaults de fechas](10-configuracion.md).

</details>

---

## Flujo recomendado para empezar el día

1. Entrás al Dashboard.
2. Si la tarjeta **Syncs pendientes** está en amarillo → revisás el sync primero.
3. Si la tarjeta **Alertas activas** está en roja → resolvés las alertas.
4. Chequeás que los totales de stock tengan sentido.
5. Si buscás un producto específico, usás el buscador o el filtro **Sin stock**.
