# Rework del módulo de inventario de salas (showrooms)

**Fecha:** 2026-06-08
**Estado:** Aprobado para planificación

## Contexto

El módulo actual de inventario (`InventoryClassifier`, `InventoryResolver`, `InventoryMovement`,
`InventorySync`, `SyncInventoryJob`) es un borrador antiguo, no usado en producción, que
clasifica entregas (consumidas vía `LogisticsApiClient` desde la API de Rutas Nalakalu) en
movimientos de entrada/salida de inventario por sala usando heurísticas de regex sobre
`order_number`, nombre de cliente y nombres de producto.

La API de entregas ahora expone datos estructurados (`source_showroom`, `destination_showroom`,
`delivery_type` como enum estable) que antes había que adivinar. Esto permite reemplazar
la heurística regex por una clasificación basada en datos estructurados + reglas configurables,
y modelar las salas como una entidad real en base de datos (como ya existe en la otra app,
Rutas Nalakalu).

Como el módulo no está en uso, se rediseña desde cero — sin necesidad de migrar datos
existentes ni mantener compatibilidad con el esquema actual (`sala` como string `SP/SE/SG`).

Objetivo: mejorar rendimiento (el cuello de botella es `ProductDecoder` recorriendo todo el
catálogo de productos por cada ítem) y usabilidad (calidad tipo ERP: intuitivo, profesional,
trazable), y alinear la lógica de clasificación con cómo realmente operan los pedidos hoy.

## Modelo de datos

### `Showroom` (nueva tabla)

```
name                    string,  required
code                    string,  required, unique (uppercased) — debe coincidir con
                                 source_showroom.code / destination_showroom.code de la API
is_main                 boolean, default: false — solo una sala puede ser is_main
order_number_prefixes   json array (ej. ["2","3"])  — usado activamente por el clasificador V1
order_number_keywords   json array — reservado para reglas futuras (expuesto en CRUD,
                                      no usado por el clasificador en V1)
inter_sala_keywords     json array — reservado para reglas futuras
product_keywords        json array — reservado para reglas futuras
active                  boolean, default: true
timestamps
```

Serializa los 4 campos JSON con `serialize ..., coder: JSON` (igual que en Rutas).
Validaciones: `name`/`code` presentes, `code` único (case-insensitive, se normaliza a
mayúsculas en `before_validation`), y solo un registro `is_main: true` simultáneamente
(al activar uno se desactiva cualquier otro).

### `InventoryMovement` (rework)

- `sala` (string `SP/SE/SG`) → `belongs_to :showroom` (FK indexada). Se elimina
  `InventoryMovement::SALAS` y `SALA_LABELS`; las etiquetas vienen de `Showroom#name`.
- Nuevo campo `source` (string enum: `"synced"` / `"manual"`) — distingue movimientos
  generados por el sync automático de los registrados manualmente por un usuario.
- Nuevo campo `flag` (string, nullable; valor inicial soportado: `"stock_missing"`) —
  bandera extensible para discrepancias, acompañada del `notes` ya existente.
- `status` (`resolved`/`unresolved`/`ignored`) conserva su semántica actual: describe si
  el *producto* fue identificado, no el estado del flujo de aprobación.

### `InventorySync`

Sin cambios estructurales. Sigue agrupando lotes de movimientos **automáticos** en
revisión (`pending_review` → `confirmed`). Los movimientos manuales no pasan por aquí
(ver "Salidas manuales").

## Clasificación automática

Se elimina toda la maquinaria de regex existente en `InventoryClassifier`
(`NALAKALU_RE`, `ESCAZU_RE`, `GUANACASTE_RE`, `CUSTOMER_ORDER_RE`, `MANDADO_RE`,
`EXIT_SALA_RE`, `detect_destination`, `exit_sala_from`, `customer_order?`, `mandado_order?`).

El nuevo `InventoryClassifier` evalúa **dos reglas independientes** por entrega
(no son fallback una de la otra — ambas se evalúan y cada una puede generar sus
propios movimientos en borrador, agrupados en un `InventorySync`):

1. **Movimiento entre salas**: si la entrega trae `source_showroom` y/o
   `destination_showroom` estructurados (mapeados por `code` a un `Showroom` local activo,
   vía caché simple `Showroom.active.index_by(&:code)`):
   - `source_showroom` presente → genera `exit` desde esa sala
   - `destination_showroom` presente → genera `entry` hacia esa sala
   - Pueden darse ambos, uno solo, o ninguno.

2. **Entrada por reabastecimiento de sala principal**: si `order_number` empieza con
   alguno de los `order_number_prefixes` configurados en el `Showroom` con `is_main: true`
   → genera `entry` hacia esa sala. Esto hace que la regla "pedidos que inician en 2 o 3 →
   sala principal" sea completamente configurable desde el CRUD (cambiar prefijos, o
   incluso qué sala es la principal, sin tocar código ni desplegar).

## Optimización de rendimiento

El cuello de botella identificado es `ProductDecoder.detect_base_product`, que recorre
todo el catálogo de productos activos (`O(items × productos)`) por cada ítem de cada
entrega procesada — el mismo patrón usado por `ProcurementResolver`, pero aquí corre
sobre rangos de fechas más amplios.

**Solución V1 (bajo riesgo, alto impacto)**: memoización por corrida en `InventoryResolver` —

```ruby
decoded_by_name = Hash.new { |h, name| h[name] = ProductDecoder.decode(name) }
```

Cada `product_name` único se decodifica **una sola vez por sync**, sin importar cuántas
entregas/ítems lo repitan (es común que muchas entregas compartan los mismos nombres de
producto). No se modifica el algoritmo interno de `ProductDecoder` (compartido con
`ProcurementResolver`), por lo que no hay riesgo de regresión en proveeduría — solo se
reduce drásticamente el número de invocaciones.

*Mejora futura (fuera de alcance de este rework)*: precalcular un índice de búsqueda
basado en tokens normalizados para que `detect_base_product` no tenga que recorrer todo
el catálogo en cada decodificación — atacaría la raíz del costo computacional, pero
implica modificar un servicio compartido y requiere más análisis/riesgo.

## Salidas manuales y discrepancias

### Flujo de registro de salida (nueva pantalla)

1. El usuario elige la **sala** de origen (`Showroom`).
2. Opcionalmente ingresa un **número de pedido** y pulsa "Consultar" → se llama a
   `LogisticsApiClient` (ej. `fetch_deliveries(order_number: ...)`) para mostrar los
   datos de la entrega (cliente, ítems, fecha) como apoyo de corroboración — no crea
   nada automáticamente, solo ayuda al usuario a verificar lo que va a registrar.
3. El usuario busca el **producto** (selector con búsqueda, siguiendo el patrón de
   pickers ya usado en la app) e ingresa la **cantidad** que sale.
4. El sistema muestra en vivo el **stock actual calculado** de ese producto en esa sala
   (reutilizando `stock_by_product_and_sala`, filtrado a `product_id` + `showroom_id`).
5. Al guardar:
   - Se crea un `InventoryMovement` con `movement_type: "exit"`, `source: "manual"`,
     `status: "resolved"` — el producto ya fue identificado al seleccionarlo del catálogo,
     por lo que **no** pasa por el ciclo de revisión de `InventorySync`. La verificación
     activa del usuario (consultar pedido, revisar stock) constituye la confirmación.
   - Si la cantidad solicitada **excede el stock calculado** (incluyendo stock = 0 /
     inexistente): se guarda igual, pero con `flag: "stock_missing"` y una nota
     automática indicando el faltante (el usuario puede ampliar el contexto).

### Vista de discrepancias ("Alertas de inventario")

Listado filtrable de `InventoryMovement.where(flag: "stock_missing")`: producto, sala,
cantidad, pedido relacionado, fecha y nota. Permite **resolver** la alerta (ej. registrando
un movimiento de ajuste/`initial` que corrija el stock, lo cual limpia el `flag`),
dejando trazabilidad de cómo se solucionó la discrepancia — no solo "qué pasó" sino
"cómo se corrigió".

## CRUD de `Showroom` y ajustes de usabilidad

**CRUD `Showroom`** (ej. `Admin::ShowroomsController`, siguiendo el patrón de otras
pantallas de administración existentes):
- Listado: nombre, código, badge "Principal" para `is_main`, estado activo/inactivo.
- Formulario: nombre, código, toggle "Es sala principal" (validación que impide tener
  dos salas principales — al activar una se desactiva la anterior, con confirmación), y
  los 4 catálogos JSON como **inputs tipo "tags"** (agregar/quitar valores individuales,
  consistente con patrones de la app — evita errores de sintaxis JSON).
- Los campos reservados para el futuro (`order_number_keywords`, `inter_sala_keywords`,
  `product_keywords`) se agrupan en una sección colapsable "Reglas avanzadas (próximamente)",
  para que quede claro cuáles reglas están activas hoy.

**Ajustes a pantallas existentes:**
- `inventories#index`: el agrupamiento de stock pasa de `sala` (string) a `showroom`
  (nombre/código vía relación), y se agregan accesos directos a "Registrar salida" y
  "Alertas de inventario" (con contador de discrepancias pendientes visible de un vistazo).
- `inventory_syncs#show`: los selectores de sala listan `Showroom.active`, mostrando
  nombre real en vez del código crudo `SP/SE/SG`.
- Se agrega indicador de **origen del movimiento** (`source: synced/manual`) en los
  listados, para distinguir de un vistazo qué generó el sistema vs. qué registró una persona.

## Testing

- Specs de modelo: `Showroom` (validaciones, unicidad de `is_main`), `InventoryMovement`
  (con `flag`/`source`/`showroom`).
- Specs de servicio: `InventoryClassifier` con fixtures de entregas con/sin
  `source_showroom`/`destination_showroom` estructurados y con distintos `order_number`
  (prefijos configurados vs. no configurados).
- Spec de `InventoryResolver` verificando memoización (un solo `ProductDecoder.decode`
  por nombre de producto único, sin importar cuántos ítems lo repitan).
- Specs de request: flujo de salida manual (con y sin stock suficiente → genera `flag`),
  CRUD de `Showroom`, vista de alertas/discrepancias.

## Fuera de alcance

- Sincronizar/migrar el catálogo de `Showroom` desde la otra app (Rutas) — se gestiona
  localmente vía CRUD.
- Reescribir `ProductDecoder` para usar un índice de búsqueda precalculado (mejora futura).
- Activar las reglas "reservadas" (`order_number_keywords`, `inter_sala_keywords`,
  `product_keywords`) en el clasificador — quedan almacenadas y configurables, pero su
  lógica de uso se define en una iteración futura.
