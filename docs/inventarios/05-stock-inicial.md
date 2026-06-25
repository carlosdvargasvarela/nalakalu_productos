# 📥 Cargar stock inicial

**Acceso:** Barra lateral → _Stock inicial_\
**Ruta:** `/inventory/initial_stock/new`

Registra el inventario de partida de una sala: la cantidad de cada producto que había en un momento determinado, ya sea al abrir el sistema, al incorporar una nueva sala, o después de un conteo físico que establece una base nueva.

{% hint style="warning" %}
**¿Cuándo usar esta pantalla y cuándo usar Ajustar inventario?**

* **Stock inicial** → cuando la sala no tiene movimientos previos en el sistema (apertura, sala nueva).
* **[Ajustar inventario](06-ajuste.md)** → cuando la sala ya tiene historial y solo querés corregir diferencias puntuales.
{% endhint %}

---

## Paso a paso

### 1. Parámetros del cargue

<table><thead><tr><th width="200">Campo</th><th width="130">Obligatorio</th><th>Descripción</th></tr></thead><tbody><tr><td><strong>Sala</strong></td><td>Sí</td><td>La sala cuyo stock estás cargando. Solo una sala por operación.</td></tr><tr><td><strong>Fecha de referencia</strong></td><td>No</td><td>Fecha en que se hizo el conteo. Por defecto: hoy.</td></tr><tr><td><strong>Notas</strong></td><td>No</td><td>Descripción del cargue. Ej: <em>"Toma de inventario apertura junio 2026"</em></td></tr></tbody></table>

---

### 2. Lista de productos

La tabla empieza con una fila vacía. Por cada producto de esa sala:

1. Seleccioná el **producto** en el menú desplegable.
2. Ingresá la **cantidad** inicial.

<kbd>+ Agregar fila</kbd> — agrega una fila para otro producto.\
<kbd>🗑</kbd> — elimina una fila (activo cuando hay más de una).

<details>

<summary>🆕 ¿El producto no existe todavía?</summary>

Hacé clic en **+** al lado del selector de producto para crear uno en el momento:

```
┌──────────────────────────────────────┐
│  ➕ Crear nuevo producto             │
│                                      │
│  Nombre *         [______________]   │
│  Código interno * [______________]   │
│  Familia          [ — Sin familia — ]│
│                                      │
│  [ Cancelar ]  [ Crear producto ]    │
└──────────────────────────────────────┘
```

Al crearlo, queda seleccionado automáticamente en esa fila.

</details>

---

### 3. Guardar

Hacé clic en <kbd>Guardar stock inicial</kbd>. El sistema registra un movimiento de tipo **Stock inicial** por cada producto en la lista. Estos movimientos quedan visibles en el historial de [Movimientos](02-movimientos.md).

---

## Notas importantes

{% hint style="info" %}
**El stock inicial suma al stock existente**, no lo reemplaza. Si la sala ya tenía movimientos previos, el cargue se agrega como un movimiento adicional.

Si querés establecer un valor exacto de stock (reemplazar lo anterior), la herramienta correcta es [Ajustar inventario](06-ajuste.md).
{% endhint %}

{% hint style="info" %}
**Una sala a la vez.** Si tenés varias salas para cargar, repetí el proceso por cada una.

Si tenés muchos productos en varias salas, la [Carga masiva por Excel](07-carga-masiva.md) puede ser más rápida — el archivo puede incluir múltiples salas.
{% endhint %}
