# 🔔 Alertas de inventario

**Acceso:** Barra lateral → _Alertas_ (en rojo cuando hay alertas activas)\
**Ruta:** `/inventory/alerts`

Las alertas son avisos automáticos que el sistema genera cuando detecta una discrepancia: específicamente, cuando se registra una salida de un producto que no tenía suficiente stock en esa sala. El sistema no bloquea la operación, pero deja un aviso para que puedas revisarlo.

---

## Cuándo aparece una alerta

{% hint style="warning" %}
Una alerta se genera automáticamente cuando registrás una salida de **X unidades** de un producto en una sala, pero esa sala tenía **menos de X unidades** según el sistema.

**Ejemplo:** Registrás la salida de 5 sofás de "Sala Norte", pero el sistema tenía registradas solo 2. La salida se registra normalmente, pero se crea una alerta de discrepancia.
{% endhint %}

---

## Pantalla sin alertas

Si no hay alertas activas, la pantalla muestra un mensaje de confirmación:

```
     ✅
   Sin alertas pendientes
   El inventario está al día. No hay discrepancias detectadas.
```

No hay nada que hacer.

---

## Pantalla con alertas

Cuando hay alertas, ves una tabla con una fila por alerta:

<table><thead><tr><th width="150">Columna</th><th>Qué muestra</th></tr></thead><tbody><tr><td><strong>Producto</strong></td><td>Producto involucrado en la discrepancia</td></tr><tr><td><strong>Sala</strong></td><td>Sala de la que se registró la salida</td></tr><tr><td><strong>Cant.</strong></td><td>Cantidad que se intentó retirar</td></tr><tr><td><strong>Pedido</strong></td><td>Número de pedido asociado, si lo había</td></tr><tr><td><strong>Fecha</strong></td><td>Fecha del movimiento que generó la alerta</td></tr><tr><td><strong>Acciones</strong></td><td>Botón para resolver individualmente</td></tr></tbody></table>

---

## Cómo resolver una alerta

{% tabs %}
{% tab title="Resolver individualmente" %}
Hacé clic en <kbd>✓ Resolver</kbd> en la fila de la alerta. Se expande un panel debajo:

```
┌──────────────────────────────────────────────────────┐
│  ☐ Registrar ajuste de stock                         │
│     Cantidad a ajustar  [_______]                    │
│                                                      │
│  Nota de resolución                                  │
│  ┌────────────────────────────────────────────────┐  │
│  │ ¿qué pasó?                                     │  │
│  └────────────────────────────────────────────────┘  │
│                                                      │
│                    [ Confirmar resolución ]          │
└──────────────────────────────────────────────────────┘
```

**Campos:**

* **Registrar ajuste de stock** (casilla opcional): si la marcás, podés ingresar una cantidad para ajustar el stock de ese producto en esa sala. Útil cuando el producto sí estaba disponible pero no estaba registrado en el sistema.
* **Nota de resolución**: describí qué pasó y cómo se resolvió.

Hacé clic en <kbd>Confirmar resolución</kbd>. La alerta desaparece del listado.
{% endtab %}

{% tab title="Resolver en lote" %}
Si hay varias alertas que simplemente querés cerrar (sin ajuste de stock):

1. Tildá las alertas que querés resolver.
2. O usá **Seleccionar todo** para marcarlas todas.
3. Hacé clic en <kbd>✓ Resolver seleccionadas</kbd>.

{% hint style="info" %}
La resolución en lote **solo marca las alertas como resueltas** — no crea ajustes de stock. Si necesitás ajustar el stock de alguna alerta puntual, resuélvela individualmente.
{% endhint %}
{% endtab %}
{% endtabs %}

---

## Cómo interpretar una alerta: dos causas típicas

{% tabs %}
{% tab title="Caso A — El stock sí estaba, pero el sistema no lo sabía" %}
El producto estaba físicamente en la sala, pero por algún motivo no estaba registrado correctamente en el sistema (cargue inicial faltante, movimiento no registrado previamente, etc.).

**Qué hacer:**
1. Confirmá que la salida fue correcta.
2. Resolvé la alerta **con ajuste de stock** por la diferencia.
3. Agregá una nota explicando la causa.
{% endtab %}

{% tab title="Caso B — El stock realmente no estaba (faltante real)" %}
La salida se registró pero el producto efectivamente no estaba en la sala. Es una pérdida real o un error de operación.

**Qué hacer:**
1. Resolvé la alerta **sin ajuste de stock** — el stock negativo ya quedó reflejado en el movimiento original.
2. Agregá una nota explicando la situación.
3. Si querés investigar más, revisá el [historial de movimientos](02-movimientos.md) de ese producto y sala.
{% endtab %}
{% endtabs %}

---

## Indicadores visuales en otros lugares

<table><thead><tr><th width="240">Dónde</th><th>Qué ves cuando hay alertas</th></tr></thead><tbody><tr><td>Tarjeta del Dashboard</td><td>Se resalta en rojo con el número de alertas activas. Clic para ir directo a esta pantalla.</td></tr><tr><td>Ícono en barra lateral</td><td>El triángulo ⚠️ cambia a rojo y muestra el contador de alertas.</td></tr><tr><td>Columna "Origen" en Movimientos</td><td>El movimiento que generó la alerta muestra un ícono ⚠️ amarillo.</td></tr></tbody></table>
