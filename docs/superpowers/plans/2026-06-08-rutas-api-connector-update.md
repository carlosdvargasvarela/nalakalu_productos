# Conector API de Rutas — Sync incremental + datos de showroom — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Actualizar el conector con la API de Rutas (`LogisticsApiClient`) para soportar los nuevos parámetros (`archived`, `updated_since`, paginación), introducir sincronización incremental basada en un cursor global de `updated_at` para resolver la lentitud de `SyncDeliveriesJob`/`SyncInventoryJob`, y aprovechar los nuevos campos estructurados `source_showroom`/`destination_showroom` en `InventoryClassifier` para detectar salas de forma confiable (con el regex actual como respaldo).

**Architecture:** Se extiende `LogisticsApiClient` con los filtros nuevos y un método paginado `fetch_updated_deliveries` que solo trae entregas modificadas desde la última corrida (usando un cursor persistido en un modelo singleton `LogisticsSyncCursor`). Los jobs de sync pasan ese cursor como `updated_since` y avanzan el cursor al `updated_at` máximo recibido. `InventoryClassifier` gana un helper `showroom_sala` que mapea `source_showroom`/`destination_showroom` (cuyo `code` coincide con los códigos internos `SP`/`SE`/`SG`) a la sala interna; cuando el campo estructurado está presente y mapea a una sala conocida, se usa como fuente primaria — si no, se conserva la heurística de regex existente.

**Tech Stack:** Ruby on Rails 7.2, Minitest (`ActiveSupport::TestCase`/`ActiveJob::TestCase`), Faraday, Active Job (Sidekiq queue `:procurement`/`:inventory`).

---

## Mapa de archivos

- Modificar: `app/services/logistics_api_client.rb` — nuevos filtros, cache key, método paginado incremental
- Crear: `db/migrate/20260608120000_create_logistics_sync_cursors.rb` — tabla singleton para el cursor
- Crear: `app/models/logistics_sync_cursor.rb` — acceso/actualización del cursor global
- Modificar: `app/jobs/sync_deliveries_job.rb` — usar `updated_since` + avanzar cursor
- Modificar: `app/jobs/sync_inventory_job.rb` — usar `updated_since` + avanzar cursor
- Modificar: `app/services/inventory_classifier.rb` — usar `source_showroom`/`destination_showroom` como fuente primaria de sala
- Crear: `test/models/logistics_sync_cursor_test.rb`
- Crear: `test/services/inventory_classifier_test.rb`
- Crear: `test/services/logistics_api_client_test.rb`

---

### Task 1: Modelo y migración para el cursor global de sync

**Files:**
- Create: `db/migrate/20260608120000_create_logistics_sync_cursors.rb`
- Create: `app/models/logistics_sync_cursor.rb`
- Test: `test/models/logistics_sync_cursor_test.rb`

- [ ] **Step 1: Escribir el test (fallará porque el modelo no existe)**

```ruby
# test/models/logistics_sync_cursor_test.rb
require "test_helper"

class LogisticsSyncCursorTest < ActiveSupport::TestCase
  setup { LogisticsSyncCursor.delete_all }

  test "current crea (o devuelve) el registro singleton" do
    cursor = LogisticsSyncCursor.current
    assert cursor.persisted?
    assert_nil cursor.last_synced_at

    assert_equal cursor, LogisticsSyncCursor.current
    assert_equal 1, LogisticsSyncCursor.count
  end

  test "advance_to! solo avanza hacia adelante en el tiempo" do
    cursor = LogisticsSyncCursor.current
    older = Time.zone.parse("2026-06-01T00:00:00Z")
    newer = Time.zone.parse("2026-06-07T00:00:00Z")

    cursor.advance_to!(newer)
    assert_equal newer, cursor.reload.last_synced_at

    cursor.advance_to!(older)
    assert_equal newer, cursor.reload.last_synced_at, "no debe retroceder el cursor"

    even_newer = Time.zone.parse("2026-06-08T00:00:00Z")
    cursor.advance_to!(even_newer)
    assert_equal even_newer, cursor.reload.last_synced_at
  end

  test "advance_to! ignora valores nil o en blanco" do
    cursor = LogisticsSyncCursor.current
    cursor.advance_to!(nil)
    assert_nil cursor.reload.last_synced_at
  end
end
```

- [ ] **Step 2: Correr el test para confirmar que falla**

Run: `bin/rails test test/models/logistics_sync_cursor_test.rb`
Expected: FAIL — `NameError: uninitialized constant LogisticsSyncCursor` (o tabla inexistente)

- [ ] **Step 3: Crear la migración**

```ruby
# db/migrate/20260608120000_create_logistics_sync_cursors.rb
class CreateLogisticsSyncCursors < ActiveRecord::Migration[7.2]
  def change
    create_table :logistics_sync_cursors do |t|
      t.datetime :last_synced_at
      t.timestamps
    end
  end
end
```

Run: `bin/rails db:migrate`
Expected: `== ... CreateLogisticsSyncCursors: migrated`

- [ ] **Step 4: Crear el modelo**

```ruby
# app/models/logistics_sync_cursor.rb
class LogisticsSyncCursor < ApplicationRecord
  def self.current
    first_or_create!
  end

  # Avanza el cursor solo si el nuevo valor es más reciente que el actual.
  # Así, una corrida que procesa entregas fuera de orden nunca retrocede
  # el punto de partida de la siguiente sincronización incremental.
  def advance_to!(timestamp)
    return if timestamp.blank?

    timestamp = timestamp.is_a?(String) ? Time.zone.parse(timestamp) : timestamp
    return if last_synced_at.present? && timestamp <= last_synced_at

    update!(last_synced_at: timestamp)
  end
end
```

- [ ] **Step 5: Correr el test para confirmar que pasa**

Run: `bin/rails test test/models/logistics_sync_cursor_test.rb`
Expected: PASS (4 runs, 0 failures, 0 errors)

- [ ] **Step 6: Commit**

```bash
git add db/migrate/20260608120000_create_logistics_sync_cursors.rb db/schema.rb \
  app/models/logistics_sync_cursor.rb test/models/logistics_sync_cursor_test.rb
git commit -m "Agregar LogisticsSyncCursor para sincronización incremental con la API de Rutas"
```

---

### Task 2: Soportar `archived`, `updated_since` y paginación en `LogisticsApiClient`

**Files:**
- Modify: `app/services/logistics_api_client.rb`
- Test: `test/services/logistics_api_client_test.rb`

- [ ] **Step 1: Escribir los tests (fallarán: los filtros nuevos aún no se envían/cachean)**

```ruby
# test/services/logistics_api_client_test.rb
require "test_helper"

class LogisticsApiClientTest < ActiveSupport::TestCase
  setup do
    Rails.cache.clear
    @client = LogisticsApiClient.new
  end

  test "clean_filters incluye archived (incluso cuando es false) y updated_since formateado" do
    cleaned = @client.send(:clean_filters,
      from: "2026-06-01",
      archived: false,
      updated_since: Time.zone.parse("2026-06-01T12:30:00Z"),
      page: 2,
      per_page: 100
    )

    assert_equal "2026-06-01", cleaned[:from]
    assert_equal false, cleaned[:archived]
    assert_equal "2026-06-01T12:30:00Z", cleaned[:updated_since]
    assert_equal 2, cleaned[:page]
    assert_equal 100, cleaned[:per_page]
  end

  test "clean_filters descarta nil y cadenas vacías pero conserva false" do
    cleaned = @client.send(:clean_filters, from: "", to: nil, archived: false, status: "ready_to_deliver")

    refute cleaned.key?(:from)
    refute cleaned.key?(:to)
    assert_equal false, cleaned[:archived]
    assert_equal "ready_to_deliver", cleaned[:status]
  end

  test "build_cache_key distingue por archived y updated_since" do
    base = @client.send(:build_cache_key, from: "2026-06-01", to: "2026-06-07")
    with_archived = @client.send(:build_cache_key, from: "2026-06-01", to: "2026-06-07", archived: true)
    with_since = @client.send(:build_cache_key, from: "2026-06-01", to: "2026-06-07", updated_since: "2026-06-01T00:00:00Z")

    refute_equal base, with_archived
    refute_equal base, with_since
    refute_equal with_archived, with_since
  end
end
```

- [ ] **Step 2: Correr los tests para confirmar que fallan**

Run: `bin/rails test test/services/logistics_api_client_test.rb`
Expected: FAIL — `assert_equal false, cleaned[:archived]` falla porque `clean_filters` actual descarta valores `blank?` (y `false.blank?` es `true`), y no reconoce `:archived`/`:updated_since`/`:page`/`:per_page`

- [ ] **Step 3: Reescribir `clean_filters` y `build_cache_key`**

Reemplazar en `app/services/logistics_api_client.rb` (líneas 56-73):

```ruby
  private

  def build_cache_key(filters)
    parts = [
      "logistics_deliveries",
      filters[:from],
      filters[:to],
      filters[:order_number],
      filters[:seller_code],
      filters[:status],
      filters[:archived],
      filters[:updated_since],
      filters[:page],
      filters[:per_page]
    ].map(&:to_s)
    parts.join("/")
  end

  FILTER_KEYS = %i[from to status order_number seller_code archived updated_since page per_page].freeze

  def clean_filters(filters)
    filters.slice(*FILTER_KEYS).each_with_object({}) do |(key, value), cleaned|
      next if value.nil?
      next if value == ""

      cleaned[key] = key == :updated_since ? format_timestamp(value) : value
    end
  end

  def format_timestamp(value)
    value.respond_to?(:iso8601) ? value.iso8601 : value.to_s
  end
```

> Nota: `filters.slice(*FILTER_KEYS).reject { |_, v| v.blank? }` se reemplaza por un filtro explícito de `nil`/`""` porque `false.blank?` es `true` en Rails — con el filtro anterior, `archived: false` se perdía silenciosamente.

- [ ] **Step 4: Correr los tests para confirmar que pasan**

Run: `bin/rails test test/services/logistics_api_client_test.rb`
Expected: PASS (3 runs, 0 failures, 0 errors)

- [ ] **Step 5: Commit**

```bash
git add app/services/logistics_api_client.rb test/services/logistics_api_client_test.rb
git commit -m "Soportar filtros archived/updated_since/paginación en LogisticsApiClient"
```

---

### Task 3: Método paginado `fetch_updated_deliveries` para sync incremental

**Files:**
- Modify: `app/services/logistics_api_client.rb`
- Test: `test/services/logistics_api_client_test.rb`

- [ ] **Step 1: Agregar test con un connection doble (fake Faraday) que pagina dos veces**

Agregar al final de `test/services/logistics_api_client_test.rb`:

```ruby
  test "fetch_updated_deliveries pagina hasta agotar X-Total-Pages y no usa cache" do
    page1 = [{ "id" => 1, "updated_at" => "2026-06-01T00:00:00Z" }]
    page2 = [{ "id" => 2, "updated_at" => "2026-06-02T00:00:00Z" }]

    responses = [
      FakeResponse.new(success: true, body: page1, headers: { "X-Total-Pages" => "2" }),
      FakeResponse.new(success: true, body: page2, headers: { "X-Total-Pages" => "2" })
    ]

    connection = FakeConnection.new(responses)
    @client.instance_variable_set(:@connection, connection)

    result = @client.fetch_updated_deliveries(since: Time.zone.parse("2026-05-01T00:00:00Z"), per_page: 1)

    assert_equal [page1.first, page2.first], result
    assert_equal 2, connection.requests.size
    assert_equal 1, connection.requests[0][:params][:page]
    assert_equal 2, connection.requests[1][:params][:page]
    assert_equal "2026-05-01T00:00:00Z", connection.requests[0][:params][:updated_since]
  end

  test "fetch_updated_deliveries detiene la paginación si una página llega vacía" do
    responses = [
      FakeResponse.new(success: true, body: [{ "id" => 1, "updated_at" => "2026-06-01T00:00:00Z" }], headers: { "X-Total-Pages" => "5" }),
      FakeResponse.new(success: true, body: [], headers: { "X-Total-Pages" => "5" })
    ]

    connection = FakeConnection.new(responses)
    @client.instance_variable_set(:@connection, connection)

    result = @client.fetch_updated_deliveries(since: Time.zone.parse("2026-05-01T00:00:00Z"), per_page: 1)

    assert_equal 1, result.size
    assert_equal 2, connection.requests.size
  end

  FakeResponse = Struct.new(:success, :body, :headers, keyword_init: true) do
    def success?
      success
    end
  end

  class FakeConnection
    attr_reader :requests

    def initialize(responses)
      @responses = responses
      @requests = []
    end

    def get(path, params = {})
      @requests << { path: path, params: params }
      @responses[@requests.size - 1]
    end
  end
```

- [ ] **Step 2: Correr los tests para confirmar que fallan**

Run: `bin/rails test test/services/logistics_api_client_test.rb`
Expected: FAIL — `NoMethodError: undefined method 'fetch_updated_deliveries'`

- [ ] **Step 3: Implementar `fetch_updated_deliveries`**

Agregar a `app/services/logistics_api_client.rb`, después de `fetch_deliveries` (después de la línea 49, antes de `self.invalidate_cache!`):

```ruby
  MAX_PER_PAGE = 200

  # Trae todas las entregas modificadas desde `since`, paginando.
  # No usa cache: está pensado para sync incremental, donde cada corrida
  # debe reflejar el estado más reciente posible.
  def fetch_updated_deliveries(since:, from: nil, to: nil, per_page: MAX_PER_PAGE)
    results = []
    page = 1

    loop do
      response = @connection.get("deliveries", clean_filters(
        from: from, to: to, updated_since: since, page: page, per_page: per_page
      ))

      break unless response.success?

      batch = Array(response.body)
      results.concat(batch)

      total_pages = response.headers["X-Total-Pages"].to_i
      break if batch.empty? || page >= total_pages

      page += 1
    end

    results
  rescue Faraday::Error => e
    Rails.logger.error "[LogisticsApiClient] fetch_updated_deliveries: #{e.message}"
    results
  end
```

- [ ] **Step 4: Correr los tests para confirmar que pasan**

Run: `bin/rails test test/services/logistics_api_client_test.rb`
Expected: PASS (5 runs, 0 failures, 0 errors)

- [ ] **Step 5: Commit**

```bash
git add app/services/logistics_api_client.rb test/services/logistics_api_client_test.rb
git commit -m "Agregar fetch_updated_deliveries paginado para sincronización incremental"
```

---

### Task 4: Usar el cursor incremental en los jobs de sync

**Files:**
- Modify: `app/jobs/sync_deliveries_job.rb`
- Modify: `app/jobs/sync_inventory_job.rb`

- [ ] **Step 1: Actualizar `SyncDeliveriesJob`**

Reemplazar el contenido de `app/jobs/sync_deliveries_job.rb`:

```ruby
# app/jobs/sync_deliveries_job.rb
class SyncDeliveriesJob < ApplicationJob
  queue_as :procurement

  def perform(from:, to:, user_id: nil)
    cursor = LogisticsSyncCursor.current
    deliveries = LogisticsApiClient.new.fetch_updated_deliveries(
      since: cursor.last_synced_at, from: from, to: to
    )

    results = deliveries.flat_map do |delivery|
      ProcurementResolver.resolve_delivery(delivery)
    end

    new_count = results.count(&:previously_new_record?)
    existing_count = results.size - new_count

    cursor.advance_to!(deliveries.filter_map { |d| d["updated_at"] }.max)

    Rails.logger.info(
      "[SyncDeliveriesJob] from=#{from} to=#{to} " \
      "nuevos=#{new_count} existentes=#{existing_count} " \
      "entregas_modificadas=#{deliveries.size}"
    )
  ensure
    ProductDecoder.clear_cache!
    ProcurementResolver.clear_cache!
  end
end
```

> El `max` sobre cadenas ISO-8601 funciona porque ese formato ordena lexicográficamente igual que cronológicamente — pero `LogisticsSyncCursor#advance_to!` igual hace `Time.zone.parse` antes de comparar, así que cualquier formato de timestamp válido es seguro.

- [ ] **Step 2: Actualizar `SyncInventoryJob`**

Reemplazar las líneas 12 y 32-34 de `app/jobs/sync_inventory_job.rb` (la llamada a `fetch_deliveries` y el bloque `ensure`):

```ruby
class SyncInventoryJob < ApplicationJob
  queue_as :inventory

  def perform(from:, to:, user_id: nil)
    sync = InventorySync.create!(
      from_date: from,
      to_date:   to,
      status:    "pending_review",
      synced_at: Time.current
    )

    cursor = LogisticsSyncCursor.current
    deliveries = LogisticsApiClient.new.fetch_updated_deliveries(
      since: cursor.last_synced_at, from: from, to: to
    )

    movements = deliveries.flat_map do |delivery|
      InventoryResolver.resolve_delivery(delivery, sync)
    end

    sync.update!(
      deliveries_processed: deliveries.size,
      movements_count:      movements.size,
      unresolved_count:     movements.count { |m| m.status == "unresolved" }
    )

    cursor.advance_to!(deliveries.filter_map { |d| d["updated_at"] }.max)

    Rails.logger.info(
      "[SyncInventoryJob] sync=#{sync.id} from=#{from} to=#{to} " \
      "entregas=#{deliveries.size} movimientos=#{movements.size} " \
      "no_resueltos=#{sync.unresolved_count}"
    )
  rescue => e
    sync&.destroy
    raise e
  ensure
    ProductDecoder.clear_cache!
  end
end
```

- [ ] **Step 3: Verificar manualmente en consola que el cursor avanza**

Run: `bin/rails runner 'puts LogisticsSyncCursor.current.inspect'`
Expected: imprime el registro singleton (existente o recién creado) con `last_synced_at: nil` en la primera corrida

- [ ] **Step 4: Commit**

```bash
git add app/jobs/sync_deliveries_job.rb app/jobs/sync_inventory_job.rb
git commit -m "Usar sincronización incremental (updated_since + cursor) en los jobs de sync de entregas"
```

---

### Task 5: Usar `source_showroom`/`destination_showroom` como fuente primaria de sala en `InventoryClassifier`

**Files:**
- Modify: `app/services/inventory_classifier.rb`
- Test: `test/services/inventory_classifier_test.rb`

- [ ] **Step 1: Escribir los tests (fallarán: el clasificador aún ignora los showrooms estructurados)**

```ruby
# test/services/inventory_classifier_test.rb
require "test_helper"

class InventoryClassifierTest < ActiveSupport::TestCase
  def item(name, qty = 1)
    { "id" => rand(100_000), "product_name" => name, "quantity_delivered" => qty }
  end

  def delivery(order_number:, client_name: "Cliente Genérico", items: [], source_showroom: nil, destination_showroom: nil)
    {
      "order_number" => order_number,
      "client" => { "name" => client_name },
      "items" => items,
      "source_showroom" => source_showroom,
      "destination_showroom" => destination_showroom
    }
  end

  test "usa destination_showroom estructurado como sala de entrada cuando el código es conocido" do
    d = delivery(
      order_number: "MOV-001",
      items: [item("Sofá 3 puestos")],
      destination_showroom: { "id" => 1, "name" => "Sala Escazú", "code" => "SE" }
    )

    results = InventoryClassifier.classify(d)
    entries = results.select { |r| r.type == "entry" }

    assert_equal 1, entries.size
    assert_equal "SE", entries.first.sala
  end

  test "usa source_showroom estructurado como (única) sala de salida cuando el código es conocido" do
    d = delivery(
      order_number: "MOV-002",
      items: [item("Sofá 3 puestos")],
      source_showroom: { "id" => 2, "name" => "Sala Palmares", "code" => "SP" }
    )

    results = InventoryClassifier.classify(d)
    exits = results.select { |r| r.type == "exit" }

    assert_equal 1, exits.size
    assert_equal "SP", exits.first.sala
  end

  test "cae al regex cuando el showroom estructurado es null" do
    d = delivery(
      order_number: "MOV-003",
      client_name: "Juan en Guanacaste",
      items: [item("Sofá 3 puestos")],
      destination_showroom: nil,
      source_showroom: nil
    )

    results = InventoryClassifier.classify(d)
    entries = results.select { |r| r.type == "entry" }

    assert_equal 1, entries.size
    assert_equal "SG", entries.first.sala, "debe seguir detectando por nombre de cliente cuando no hay dato estructurado"
  end

  test "cae al regex cuando el código del showroom estructurado no es una sala conocida" do
    d = delivery(
      order_number: "MOV-004",
      items: [item("tomar de SE"), item("Silla comedor")],
      source_showroom: { "id" => 9, "name" => "Bodega Central", "code" => "BOD" },
      destination_showroom: nil
    )

    results = InventoryClassifier.classify(d)
    exits = results.select { |r| r.type == "exit" }

    assert_equal 1, exits.size
    assert_equal "SE", exits.first.sala, "código de showroom no rastreado en inventario -> usar regex de respaldo"
  end

  test "entregas a clientes (PED-) sin destination_showroom no generan entrada" do
    d = delivery(
      order_number: "PED-12345",
      items: [item("Sofá 3 puestos")],
      destination_showroom: nil
    )

    results = InventoryClassifier.classify(d)
    assert results.none? { |r| r.type == "entry" }
  end
end
```

- [ ] **Step 2: Correr los tests para confirmar que fallan**

Run: `bin/rails test test/services/inventory_classifier_test.rb`
Expected: FAIL — los primeros dos tests fallan porque `entries.first.sala`/`exits.first.sala` no coinciden con `SE`/`SP` (el clasificador actual ignora `source_showroom`/`destination_showroom` y usa solo el regex)

- [ ] **Step 3: Reescribir `InventoryClassifier` para usar los showrooms estructurados como fuente primaria**

Reemplazar el contenido completo de `app/services/inventory_classifier.rb`:

```ruby
class InventoryClassifier
  NALAKALU_RE    = /nalakal[uú]|na\s+lakal[uú]/i
  ESCAZU_RE      = /esc[aá]z[uú]/i
  GUANACASTE_RE  = /guanacaste/i
  CUSTOMER_ORDER_RE = /\APED-/i
  MANDADO_RE     = /\Amandado/i

  EXIT_SALA_RE = {
    "SP" => /\bSP\b|sala\s*palmares|tomar\s+de\s+SP/i,
    "SE" => /\bSE\b|sala\s*esc[aá]z[uú]|tomar\s+de\s+SE/i,
    "SG" => /\bSG\b|sala\s*guanacaste|tomar\s+de\s+SG/i
  }.freeze

  Result = Struct.new(:type, :sala, :item, keyword_init: true)

  def self.classify(delivery)
    new(delivery).classify
  end

  def initialize(delivery)
    @delivery     = delivery
    @order_number = delivery["order_number"].to_s
    @client_name  = delivery.dig("client", "name").to_s
  end

  def classify
    results      = []
    destination  = entry_destination
    source_salas = exit_salas

    items = Array(@delivery["items"])

    items.each do |item|
      next if exit_sala_from(item["product_name"].to_s)  # skip indicator lines
      next if item["quantity_delivered"].to_f <= 0

      results << Result.new(type: "entry", sala: destination, item: item) if destination

      source_salas.each_key do |sala|
        results << Result.new(type: "exit", sala: sala, item: item)
      end
    end

    results
  end

  private

  # Sala de entrada: prioriza el dato estructurado de la API de Rutas
  # (destination_showroom). Si no viene o su código no corresponde a una
  # sala que rastreamos en inventario, conserva la heurística por regex.
  def entry_destination
    showroom_sala(@delivery["destination_showroom"]) || regex_entry_destination
  end

  def regex_entry_destination
    # PED- orders are customer deliveries — no inventory entry
    return nil if customer_order?
    # Mandado orders don't affect sala inventory
    return nil if mandado_order?

    detect_destination
  end

  # Salas de salida: prioriza source_showroom (single sala estructurada);
  # si no viene o no es una sala rastreada, conserva la detección por regex
  # sobre las líneas indicadoras de los ítems ("tomar de SE", etc.).
  def exit_salas
    sala = showroom_sala(@delivery["source_showroom"])
    return { sala => true } if sala

    salas = {}
    Array(@delivery["items"]).each do |item|
      detected = exit_sala_from(item["product_name"].to_s)
      salas[detected] = true if detected
    end
    salas
  end

  # Mapea un showroom estructurado ({"id" => .., "name" => .., "code" => ..})
  # a la sala interna (SP/SE/SG). El `code` de la API de Rutas coincide con
  # los códigos internos; si no es uno de los que rastreamos, devuelve nil
  # para que el llamador caiga al respaldo por regex.
  def showroom_sala(showroom)
    return nil unless showroom.is_a?(Hash)

    code = showroom["code"].to_s
    InventoryMovement::SALAS.include?(code) ? code : nil
  end

  def detect_destination
    return "SE" if @client_name.match?(ESCAZU_RE)
    return "SG" if @client_name.match?(GUANACASTE_RE)
    "SP"
  end

  def customer_order?
    @order_number.match?(CUSTOMER_ORDER_RE)
  end

  def mandado_order?
    @order_number.match?(MANDADO_RE)
  end

  def exit_sala_from(product_name)
    EXIT_SALA_RE.each { |sala, re| return sala if product_name.match?(re) }
    nil
  end
end
```

- [ ] **Step 4: Correr los tests para confirmar que pasan**

Run: `bin/rails test test/services/inventory_classifier_test.rb`
Expected: PASS (6 runs, 0 failures, 0 errors)

- [ ] **Step 5: Correr toda la suite de inventario para detectar regresiones**

Run: `bin/rails test test/services/inventory_classifier_test.rb test/models/inventory_movement_test.rb`
Expected: PASS, 0 failures, 0 errors

- [ ] **Step 6: Commit**

```bash
git add app/services/inventory_classifier.rb test/services/inventory_classifier_test.rb
git commit -m "Usar source_showroom/destination_showroom estructurados como fuente primaria de sala en InventoryClassifier"
```

---

## Validación final

- [ ] **Step 1: Correr toda la suite relacionada**

Run: `bin/rails test test/models/logistics_sync_cursor_test.rb test/services/logistics_api_client_test.rb test/services/inventory_classifier_test.rb`
Expected: PASS, 0 failures, 0 errors

- [ ] **Step 2: Verificar que `db/schema.rb` quedó actualizado y commiteado**

Run: `git status db/schema.rb`
Expected: sin cambios pendientes (ya incluido en el commit de Task 1)

- [ ] **Step 3: Actualizar el grafo de Graphify**

Run: `graphify update .`
Expected: actualiza `graphify-out/` reflejando los archivos nuevos/modificados (sin costo de API)
