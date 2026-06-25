# 📋 Movimientos — Historial de inventario

**Acceso:** Barra lateral → _Movimientos_\
**Ruta:** `/inventory/movements`

El registro completo de todo lo que pasó en el inventario. Cada entrada, salida y ajuste queda guardado con fecha, sala, producto, cantidad y origen. Es la fuente de verdad para auditorías y para entender por qué el stock de un producto tiene el valor que tiene.

{% hint style="info" %}
El historial muestra hasta **300 movimientos** a la vez. Si tu búsqueda supera ese límite, verás un badge amarillo _"Limit 300"_ — acotar el rango de fechas o filtrar por producto te ayuda a encontrar lo que buscás.
{% endhint %}

---

## Filtros disponibles

Antes de la tabla hay un panel de filtros que podés combinar libremente:

<table data-full-width="false"><thead><tr><th width="160">Filtro</th><th>Opciones</th></tr></thead><tbody><tr><td><strong>Sala</strong></td><td>Una sala en particular o <em>Todas</em></td></tr><tr><td><strong>Producto</strong></td><td>Un producto específico o <em>Todos</em></td></tr><tr><td><strong>Tipo</strong></td><td>Entrada / Salida / Stock inicial / Todos</td></tr><tr><td><strong>Desde / Hasta</strong></td><td>Rango de fechas del movimiento</td></tr></tbody></table>

Hacé clic en 🔍 para aplicar. El botón **✕** (aparece cuando hay filtros activos) limpia todo y vuelve al listado completo.

---

## Columnas de la tabla

Los movimientos se muestran con una fila por registro y estas columnas:

| Columna | Qué muestra |
|---------|-------------|
| **Fecha** | Fecha del movimiento |
| **Tipo** | Badge de color: Entrada (verde), Salida (rojo), Stock inicial (azul) |
| **Sala** | Sala a la que pertenece el movimiento |
| **Producto** | Nombre del producto |
| **Cant.** | Cantidad en unidades |
| **Origen** | _Manual_ si lo ingresaste vos, _Sync_ si vino de importación |
| **Pedido** | Número de pedido asociado (si aplica) |
| **Notas** | Observaciones adicionales |

{% hint style="warning" %}
El ícono ⚠️ en la columna **Origen** indica que ese movimiento tiene una alerta de stock insuficiente. Podés ver y resolver las alertas en la sección [Alertas](09-alertas.md).
{% endhint %}

---

## Acciones en lote

Las acciones en lote solo funcionan con movimientos de **origen Manual** — los de sync no se pueden modificar desde esta pantalla.

Cuando hay movimientos manuales en el listado, aparece una barra de acciones encima de la tabla:

```
☐ Seleccionar todo   0 seleccionado(s)
[ 🗑 Eliminar ]  [ 📊 Exportar ]  [ ↔ Reasignar sala ]  [ ✏️ Editar nota/pedido ]
```

**Para usar cualquier acción:**
1. Tildá las casillas de los movimientos que querés afectar.
2. O usá **Seleccionar todo** para marcarlos todos de una vez.
3. Elegí la acción correspondiente.

{% tabs %}
{% tab title="🗑 Eliminar" %}
Borra permanentemente los movimientos manuales seleccionados. El sistema pide confirmación antes de proceder.

{% hint style="danger" %}
**Esta acción no se puede deshacer.** Usala solo si el movimiento fue ingresado por error. Al eliminar un movimiento, el stock se recalcula automáticamente.
{% endhint %}
{% endtab %}

{% tab title="📊 Exportar" %}
Descarga un archivo **Excel** con los movimientos seleccionados.

Útil para:
* Generar reportes para otras áreas.
* Llevar un registro externo o archivo histórico.
* Compartir datos sin dar acceso al sistema.

El archivo incluye todas las columnas: fecha, tipo, sala, producto, cantidad, origen, pedido y notas.
{% endtab %}

{% tab title="↔ Reasignar sala" %}
Mueve los movimientos seleccionados a otra sala, sin eliminarlos ni modificar la cantidad.

Se abre un diálogo para elegir la **nueva sala**:

```
┌─────────────────────────────────┐
│  Reasignar sala                 │
│                                 │
│  Nueva sala  [ — Seleccione — ] │
│                                 │
│  Solo aplica a movimientos      │
│  manuales seleccionados.        │
│                                 │
│  [ Cancelar ]  [ Reasignar ]   │
└─────────────────────────────────┘
```

Útil cuando un movimiento fue registrado en la sala incorrecta.
{% endtab %}

{% tab title="✏️ Editar nota/pedido" %}
Actualiza el número de pedido y/o la nota de varios movimientos a la vez.

```
┌─────────────────────────────────────────┐
│  Editar nota / pedido                   │
│                                         │
│  Pedido  [_______________________]      │
│  Nota    [                         ]    │
│          [_________________________]    │
│                                         │
│  Los campos en blanco no se modifican.  │
│                                         │
│  [ Cancelar ]  [ Guardar ]             │
└─────────────────────────────────────────┘
```

Si dejás un campo vacío, ese campo no se toca en los registros seleccionados.
{% endtab %}
{% endtabs %}

---

## Consejos

<details>

<summary>💡 ¿Cómo encontrar rápido el historial de un producto?</summary>

Dos opciones:

1. **Desde el Dashboard**: hacé clic en el nombre del producto en la tabla de stock. Se abre un panel con su historial completo sin salir de la pantalla.
2. **Desde Movimientos**: usá el filtro **Producto** + un rango de fechas para acotar los resultados.

</details>

<details>

<summary>💡 ¿Por qué no puedo editar un movimiento de Sync?</summary>

Los movimientos de origen **Sync** son de solo lectura una vez que se confirmaron. Si hay un error en un movimiento de sync ya confirmado, la forma de corregirlo es:

1. Ir a [Ajustar inventario](06-ajuste.md) y corregir la cantidad real.
2. O eliminar el movimiento manual que lo acompaña si aplica.

Para gestionar los movimientos de un sync **antes** de confirmarlos, usá la pantalla de [Revisión de sync](08-revision-sync.md).

</details>
