# ✏️ Ajustar inventario

**Acceso:** Barra lateral → _Ajustar inventario_\
**Ruta:** `/inventory/adjustments/new`

Corregí el stock cuando la cantidad que muestra el sistema no coincide con lo que hay físicamente. Se usa después de un conteo físico o para registrar pérdidas, daños u otros eventos que cambiaron el inventario sin quedar registrados de otra manera.

---

## Cuándo usarlo

{% tabs %}
{% tab title="✅ Casos ideales" %}
* Después de un conteo físico periódico (mensual, trimestral, etc.)
* Cuando encontrás un producto dañado o faltante
* Para corregir errores de registro detectados a posteriori
* Cuando el stock quedó desincronizado con la realidad por cualquier motivo
{% endtab %}

{% tab title="❌ Cuándo NO usarlo" %}
* Si querés registrar una salida de venta → usá [Registrar salida](04-registrar-salida.md)
* Si es el primer inventario de una sala → usá [Stock inicial](05-stock-inicial.md)
* Si el error viene de un sync que todavía no confirmaste → corregilo en [Revisión de sync](08-revision-sync.md) antes de confirmar
{% endtab %}
{% endtabs %}

---

## Paso a paso

### 1. Motivo del ajuste _(opcional)_

Antes de la tabla hay un campo libre. Describí brevemente por qué estás ajustando:

> _"Conteo físico mensual junio 2026"_\
> _"Daño en tránsito — producto roto"_\
> _"Ajuste por faltante detectado en sala"_

Esta nota queda registrada en cada movimiento de ajuste que se genere.

---

### 2. Ingresar las cantidades reales

La tabla muestra todos los productos con stock, con una columna por sala. Cada celda tiene:

```
          Actual: 5
         ┌──────────┐
         │    3     │  ← Cantidad real que contaste
         └──────────┘
```

{% hint style="success" %}
**Solo completás los campos donde el valor real difiere del sistema.** Los campos vacíos se ignoran — ese producto en esa sala no se toca.
{% endhint %}

**Ejemplos de cómo interpreta el sistema:**

{% tabs %}
{% tab title="Tenés menos de lo que dice el sistema" %}
| Sistema dice | Contaste | Ingresás | Resultado |
|-------------|----------|----------|-----------|
| 5 unidades  | 3        | `3`      | Movimiento de **−2** (ajuste negativo) |

El sistema reduce el stock a 3.
{% endtab %}

{% tab title="Tenés más de lo que dice el sistema" %}
| Sistema dice | Contaste | Ingresás | Resultado |
|-------------|----------|----------|-----------|
| 5 unidades  | 7        | `7`      | Movimiento de **+2** (ajuste positivo) |

El sistema sube el stock a 7.
{% endtab %}

{% tab title="El valor coincide" %}
| Sistema dice | Contaste | Ingresás | Resultado |
|-------------|----------|----------|-----------|
| 5 unidades  | 5        | `5` o vacío | **Sin cambio** |

No se genera ningún movimiento.
{% endtab %}
{% endtabs %}

---

### 3. Verificar antes de confirmar

Al pie de la tabla hay un **contador de cambios** que se actualiza en tiempo real:

```
3 cambio(s) pendiente(s) de aplicar      [ Cancelar ]  [ ✓ Aplicar ajustes ]
```

Revisá que el número de cambios tenga sentido con lo que ingresaste antes de confirmar.

---

### 4. Aplicar ajustes

Hacé clic en <kbd>Aplicar ajustes</kbd>. El sistema pide confirmación y luego:

* Crea un movimiento de ajuste por cada celda que modificaste.
* Actualiza el stock **de inmediato**.
* Los ajustes quedan en el historial de [Movimientos](02-movimientos.md) con origen _Manual_.

---

## Buscar un producto

El buscador en el encabezado de la tabla filtra por nombre en tiempo real, sin recargar la página. Útil cuando hay muchos productos.

---

## Notas importantes

{% hint style="info" %}
Los ajustes **no se pueden deshacer directamente**, pero podés hacer un nuevo ajuste con el valor original para revertir el efecto. El historial de movimientos queda intacto con ambas operaciones registradas.
{% endhint %}

{% hint style="warning" %}
Si la pantalla aparece vacía ("Sin productos con stock"), es porque ninguna sala tiene stock registrado todavía. Primero cargá un [Stock inicial](05-stock-inicial.md) o confirmá una sincronización.
{% endhint %}
