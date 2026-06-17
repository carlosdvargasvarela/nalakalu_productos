# Carga Masiva de Inventario por Excel — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let a sala-admin user upload an `.xlsx` file with inventory movements (entry / exit / transfer between salas), have it processed into a reviewable draft, correct/confirm it in the existing sync-review screen, and download a blank `.xlsx` template.

**Architecture:** Reuse `InventorySync` as the draft container (add a `kind` column: `logistics_sync` vs `bulk_upload`) and reuse `Inventory::SyncsController#show`/`confirm`/`confirm_matched`/`bulk_ignore`/`destroy` unchanged. A new `InventoryBulkImportService` reads the uploaded file (via a new `XlsxImportHelper` built on the `roo` gem), resolves showrooms/products per row using the rules below, and creates `InventoryMovement` records attached to a new `bulk_upload` sync — processed synchronously in the request (no background job), so the user lands directly on the review screen. A new `InventoryBulkImportTemplateService` (using `caxlsx`) generates the downloadable template.

**Tech Stack:** Rails 7.2.3, Minitest + fixtures, `roo` (read `.xlsx`), `caxlsx` (write `.xlsx`), existing `CsvImportHelper` utility methods.

## Global Constraints

- Only `.xlsx` is supported for upload and for the downloadable template (no `.csv`/`.ods` for this feature).
- Required columns (Spanish headers, normalized via `CsvImportHelper.normalize_header`): `Sala receptora (Entradas)` → `sala_receptora_entradas`, `Sala emisora (Salidas)` → `sala_emisora_salidas`, `Código producto` → `codigo_producto`, `Nombre de producto` → `nombre_de_producto`, `Cantidad` → `cantidad`. Optional: `Pedido` → `pedido`, `Fecha del movimiento` → `fecha_del_movimiento`.
- Showroom matching is by `code` or `name`, case-insensitive, against `Showroom.active` only. A filled showroom column that doesn't match any active showroom discards the entire row (hard error, not resolvable in the review screen).
- Product matching: if `Código producto` is present, match **only** by `base_code` (no fallback to name, even on failure). If it's blank, match by `Nombre de producto` (exact, case-insensitive). If no product is found, the movement is still created with `product_id: nil`, `status: "unresolved"` (resolvable later in the review screen) — never auto-created.
- All bulk-import movements get `source: "manual"`. Movements with a resolved product get `status: "resolved"`; the `InventorySync` itself stays `"pending_review"` regardless, so nothing affects stock (`confirmed_only` scope) until the existing "Confirmar y aplicar" action is used.
- Processing is synchronous in the controller request — no `ActiveJob`.
- Spanish UI copy throughout (matches the rest of the app).

---

### Task 1: `InventorySync.kind` + `import_errors`

**Files:**
- Create: `db/migrate/20260617000001_add_kind_and_import_errors_to_inventory_syncs.rb`
- Modify: `app/models/inventory_sync.rb`
- Test: `test/models/inventory_sync_test.rb` (new file)

**Interfaces:**
- Produces: `InventorySync::KINDS` (`%w[logistics_sync bulk_upload]`), `InventorySync#bulk_upload?`, `InventorySync#kind` (default `"logistics_sync"`), `InventorySync#import_errors` (json array, default `[]`).

- [ ] **Step 1: Write the failing test**

```ruby
# test/models/inventory_sync_test.rb
require "test_helper"

class InventorySyncTest < ActiveSupport::TestCase
  def build_sync(attrs = {})
    InventorySync.new({
      from_date: Date.current, to_date: Date.current, status: "pending_review"
    }.merge(attrs))
  end

  test "defaults kind to logistics_sync and import_errors to empty array" do
    sync = InventorySync.create!(from_date: Date.current, to_date: Date.current, status: "pending_review")
    assert_equal "logistics_sync", sync.kind
    assert_equal [], sync.import_errors
    assert_not sync.bulk_upload?
  end

  test "accepts kind bulk_upload" do
    sync = build_sync(kind: "bulk_upload")
    assert sync.valid?
    assert sync.bulk_upload?
  end

  test "rejects unknown kind" do
    sync = build_sync(kind: "weird")
    assert_not sync.valid?
    assert_includes sync.errors[:kind], "is not included in the list"
  end

  test "stores import_errors as an array" do
    sync = InventorySync.create!(
      from_date: Date.current, to_date: Date.current, status: "pending_review",
      kind: "bulk_upload", import_errors: ["Fila 3: sala no encontrada."]
    )
    assert_equal ["Fila 3: sala no encontrada."], sync.reload.import_errors
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bin/rails test test/models/inventory_sync_test.rb`
Expected: FAIL — `unknown attribute 'kind'` (column doesn't exist yet).

- [ ] **Step 3: Create the migration**

```ruby
# db/migrate/20260617000001_add_kind_and_import_errors_to_inventory_syncs.rb
class AddKindAndImportErrorsToInventorySyncs < ActiveRecord::Migration[7.2]
  def change
    add_column :inventory_syncs, :kind, :string, default: "logistics_sync", null: false
    add_column :inventory_syncs, :import_errors, :json, default: []
  end
end
```

Run: `bin/rails db:migrate`
Expected: `== AddKindAndImportErrorsToInventorySyncs: migrated`

- [ ] **Step 4: Update the model**

```ruby
# app/models/inventory_sync.rb
class InventorySync < ApplicationRecord
  has_many :inventory_movements, dependent: :destroy

  STATUSES = %w[pending_review confirmed].freeze
  KINDS    = %w[logistics_sync bulk_upload].freeze

  validates :status, inclusion: { in: STATUSES }
  validates :kind, inclusion: { in: KINDS }
  validates :from_date, :to_date, presence: true

  scope :pending, -> { where(status: "pending_review") }
  scope :confirmed, -> { where(status: "confirmed") }
  scope :ordered, -> { order(synced_at: :desc) }

  def confirm!
    return false if inventory_movements.unresolved.any?
    update!(status: "confirmed")
    InventoryMovement.bust_stock_cache!
    true
  end

  def confirmable?
    inventory_movements.unresolved.none?
  end

  def status_label
    status == "confirmed" ? "Confirmado" : "Pendiente revisión"
  end

  def bulk_upload?
    kind == "bulk_upload"
  end
end
```

- [ ] **Step 5: Run test to verify it passes**

Run: `bin/rails test test/models/inventory_sync_test.rb`
Expected: PASS (4 runs, 0 failures)

- [ ] **Step 6: Commit**

```bash
git add db/migrate/20260617000001_add_kind_and_import_errors_to_inventory_syncs.rb db/schema.rb app/models/inventory_sync.rb test/models/inventory_sync_test.rb
git commit -m "Agregar kind e import_errors a InventorySync para soportar cargas masivas"
```

---

### Task 2: Extract `InventoryMovement.flag_if_stock_missing!`

**Files:**
- Modify: `app/models/inventory_movement.rb`
- Modify: `app/controllers/inventory/exits_controller.rb`
- Test: `test/models/inventory_movement_test.rb`

**Interfaces:**
- Consumes: `InventoryMovement.current_stock_for(product_id:, showroom_id:)` (existing).
- Produces: `InventoryMovement.flag_if_stock_missing!(movement)` — class method, mutates and returns the given (unsaved) movement; sets `flag`/`notes` when an `exit` movement's quantity exceeds current stock. No-op (returns movement unchanged) for any other `movement_type`, or when `product_id`/`showroom_id` is missing.

This is a pure refactor: the existing behavior in `Inventory::ExitsController#apply_stock_flag!` moves onto the model unchanged, so `InventoryBulkImportService` (Task 5) can reuse it too.

- [ ] **Step 1: Write the failing test**

```ruby
# test/models/inventory_movement_test.rb — add inside the existing class, after the stock_by_product_and_showroom test

  test "flag_if_stock_missing! marca exit con stock insuficiente y deja notes" do
    movement = build_movement(movement_type: "exit", quantity: 3)
    InventoryMovement.flag_if_stock_missing!(movement)

    assert_equal "stock_missing", movement.flag
    assert_match "Alerta automática", movement.notes
  end

  test "flag_if_stock_missing! no marca exit con stock suficiente" do
    InventoryMovement.create!(movement_type: "entry", showroom: @showroom, product: @product,
      quantity: 10, status: "resolved", source: "manual", delivery_date: Date.current)

    movement = build_movement(movement_type: "exit", quantity: 3)
    InventoryMovement.flag_if_stock_missing!(movement)

    assert_nil movement.flag
  end

  test "flag_if_stock_missing! es no-op para movimientos que no son exit" do
    movement = build_movement(movement_type: "entry", quantity: 999)
    InventoryMovement.flag_if_stock_missing!(movement)

    assert_nil movement.flag
  end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bin/rails test test/models/inventory_movement_test.rb`
Expected: FAIL — `NoMethodError: undefined method 'flag_if_stock_missing!' for InventoryMovement:Class`

- [ ] **Step 3: Add the method to the model**

```ruby
# app/models/inventory_movement.rb — add inside the class, near current_stock_for

  def self.flag_if_stock_missing!(movement)
    return movement unless movement.movement_type == "exit" &&
      movement.product_id.present? && movement.showroom_id.present?

    available = current_stock_for(product_id: movement.product_id, showroom_id: movement.showroom_id)
    return movement if movement.quantity.to_f <= available

    movement.flag = "stock_missing"
    movement.notes = [
      movement.notes.presence,
      "Alerta automática: salida de #{movement.quantity} pero stock calculado era #{available}."
    ].compact.join("\n\n")
    movement
  end
```

- [ ] **Step 4: Run test to verify it passes**

Run: `bin/rails test test/models/inventory_movement_test.rb`
Expected: PASS (9 runs, 0 failures)

- [ ] **Step 5: Update `Inventory::ExitsController` to use the model method**

In `app/controllers/inventory/exits_controller.rb`, replace the call site and delete the private method:

```ruby
# replace this line inside #create:
      apply_stock_flag!(m)
# with:
      InventoryMovement.flag_if_stock_missing!(m)
```

Delete the now-unused private method entirely:

```ruby
  def apply_stock_flag!(movement)
    return unless movement.product_id.present? && movement.showroom_id.present?
    available = InventoryMovement.current_stock_for(
      product_id: movement.product_id, showroom_id: movement.showroom_id
    )
    return if movement.quantity.to_f <= available
    movement.flag = "stock_missing"
    movement.notes = [
      movement.notes.presence,
      "Alerta automática: salida de #{movement.quantity} pero stock calculado era #{available}."
    ].compact.join("\n\n")
  end
```

- [ ] **Step 6: Run the existing exits controller tests to confirm no regression**

Run: `bin/rails test test/controllers/inventory_exits_controller_test.rb`
Expected: PASS (6 runs, 0 failures) — behavior is identical, just relocated.

- [ ] **Step 7: Commit**

```bash
git add app/models/inventory_movement.rb app/controllers/inventory/exits_controller.rb test/models/inventory_movement_test.rb
git commit -m "Extraer flag_if_stock_missing! a InventoryMovement para reusarlo en carga masiva"
```

---

### Task 3: `roo` gem + `XlsxImportHelper`

**Files:**
- Modify: `Gemfile`, `Gemfile.lock` (via `bundle install`)
- Create: `app/helpers/xlsx_import_helper.rb`
- Test: `test/helpers/xlsx_import_helper_test.rb` (new file)

**Interfaces:**
- Consumes: `CsvImportHelper.normalize_header(header)` (existing).
- Produces: `XlsxImportHelper.read_xlsx(file_path)` → `{rows: [Hash], errors: [String]}`, same shape as `CsvImportHelper.read_csv`. Each row hash has normalized-header string keys and stringified values (so callers can reuse `CsvImportHelper.normalize_string`/`to_decimal` on them). Rows that are entirely blank are skipped.

We add `caxlsx` in this task too (used only by tests here, and by Task 6's template service) so both new gems land in one Gemfile change.

- [ ] **Step 1: Add the gems**

```ruby
# Gemfile — add right after `gem "csv"` in the "Utilidades" section
gem "csv"
gem "roo"
gem "caxlsx"
gem "tzinfo-data", platforms: %i[windows jruby]
```

Run: `bundle install`
Expected: `Bundle complete!` with `roo` and `caxlsx` (and their dependencies, e.g. `nokogiri`, `rubyzip`) listed as installed.

- [ ] **Step 2: Write the failing test**

```ruby
# test/helpers/xlsx_import_helper_test.rb
require "test_helper"
require "caxlsx"

class XlsxImportHelperTest < ActiveSupport::TestCase
  def write_xlsx(headers, rows)
    path = Rails.root.join("tmp", "test_xlsx_#{SecureRandom.hex(4)}.xlsx").to_s
    Axlsx::Package.new do |p|
      p.workbook.add_worksheet(name: "Carga") do |sheet|
        sheet.add_row headers if headers
        rows.each { |r| sheet.add_row r }
      end
    end.serialize(path)
    path
  end

  test "lee filas normalizando encabezados y descarta filas completamente vacías" do
    path = write_xlsx(
      ["Código producto", "Cantidad"],
      [["SOF-001", 2], [nil, nil], ["SOF-002", 3]]
    )

    result = XlsxImportHelper.read_xlsx(path)

    assert_empty result[:errors]
    assert_equal 2, result[:rows].size
    assert_equal "SOF-001", result[:rows][0]["codigo_producto"]
    assert_equal "2", result[:rows][0]["cantidad"]
    assert_equal "SOF-002", result[:rows][1]["codigo_producto"]
  ensure
    File.delete(path) if path && File.exist?(path)
  end

  test "reporta error cuando el archivo no tiene ni encabezados" do
    path = write_xlsx(nil, [])

    result = XlsxImportHelper.read_xlsx(path)

    assert_includes result[:errors], "El archivo está vacío."
    assert_empty result[:rows]
  ensure
    File.delete(path) if path && File.exist?(path)
  end

  test "reporta error legible cuando el archivo no se puede abrir" do
    result = XlsxImportHelper.read_xlsx("/tmp/no-existe-#{SecureRandom.hex(4)}.xlsx")

    assert_equal 1, result[:errors].size
    assert_match "Error al leer el archivo Excel", result[:errors].first
  end
end
```

- [ ] **Step 3: Run test to verify it fails**

Run: `bin/rails test test/helpers/xlsx_import_helper_test.rb`
Expected: FAIL — `NameError: uninitialized constant XlsxImportHelper`

- [ ] **Step 4: Implement the helper**

```ruby
# app/helpers/xlsx_import_helper.rb
require "roo"

module XlsxImportHelper
  def self.read_xlsx(file_path)
    sheet = Roo::Excelx.new(file_path).sheet(0)
    return {rows: [], errors: ["El archivo está vacío."]} if (sheet.last_row || 0) < 1

    headers = sheet.row(1).map { |h| CsvImportHelper.normalize_header(h.to_s) }
    rows = []

    (2..sheet.last_row).each do |i|
      values = sheet.row(i)
      next if values.compact.all? { |v| v.to_s.strip.empty? }

      row = {}
      headers.each_with_index { |header, idx| row[header] = values[idx].to_s.strip }
      rows << row
    end

    {rows: rows, errors: []}
  rescue => e
    {rows: [], errors: ["Error al leer el archivo Excel: #{e.message}"]}
  end
end
```

- [ ] **Step 5: Run test to verify it passes**

Run: `bin/rails test test/helpers/xlsx_import_helper_test.rb`
Expected: PASS (3 runs, 0 failures)

- [ ] **Step 6: Commit**

```bash
git add Gemfile Gemfile.lock app/helpers/xlsx_import_helper.rb test/helpers/xlsx_import_helper_test.rb
git commit -m "Agregar gems roo/caxlsx y XlsxImportHelper para leer archivos xlsx"
```

---

### Task 4: `InventoryBulkImportService` — resolución de sala/producto y filas de una sola dirección

**Files:**
- Create: `app/services/inventory_bulk_import_service.rb`
- Test: `test/services/inventory_bulk_import_service_test.rb` (new file)

**Interfaces:**
- Consumes: `XlsxImportHelper.read_xlsx(path)` (Task 3), `CsvImportHelper.normalize_string/to_decimal/validate_headers` (existing), `Showroom.active`, `Product`, `InventorySync` (`kind:`, Task 1).
- Produces: `InventoryBulkImportService.call(file_path)` → `InventoryBulkImportService::Result` (`Struct.new(:sync, :file_errors, keyword_init: true)`). `result.sync` is `nil` when the file/headers are invalid or there isn't a single valid row (and then `result.file_errors` holds the reasons); otherwise it's the persisted `InventorySync` with its `inventory_movements` already created. This task covers single-direction rows only (either showroom column, not both) — Task 5 adds transfers, `Pedido`/synthetic `order_number`, stock-flagging and sync stat finalization on top of the same class.

- [ ] **Step 1: Write the failing tests**

```ruby
# test/services/inventory_bulk_import_service_test.rb
require "test_helper"
require "caxlsx"

class InventoryBulkImportServiceTest < ActiveSupport::TestCase
  HEADERS = [
    "Sala receptora (Entradas)", "Sala emisora (Salidas)",
    "Código producto", "Nombre de producto", "Cantidad", "Pedido", "Fecha del movimiento"
  ].freeze

  setup do
    @palmares = showrooms(:palmares)
    @escazu   = showrooms(:escazu)
    @product  = products(:one)
  end

  def write_xlsx(headers, rows)
    path = Rails.root.join("tmp", "test_bulk_service_#{SecureRandom.hex(4)}.xlsx").to_s
    Axlsx::Package.new do |p|
      p.workbook.add_worksheet(name: "Carga") do |sheet|
        sheet.add_row headers if headers
        rows.each { |r| sheet.add_row r }
      end
    end.serialize(path)
    path
  end

  test "fila con solo sala receptora genera un movimiento entry resuelto por código" do
    path = write_xlsx(HEADERS, [[@escazu.name, "", @product.base_code, @product.name, 3, "", ""]])
    result = InventoryBulkImportService.call(path)

    assert result.sync
    assert_equal "bulk_upload", result.sync.kind
    movements = result.sync.inventory_movements
    assert_equal 1, movements.count
    m = movements.first
    assert_equal "entry", m.movement_type
    assert_equal @escazu, m.showroom
    assert_equal @product, m.product
    assert_equal "resolved", m.status
    assert_equal "manual", m.source
  ensure
    File.delete(path) if path && File.exist?(path)
  end

  test "fila con solo sala emisora genera un movimiento exit" do
    path = write_xlsx(HEADERS, [["", @palmares.name, @product.base_code, @product.name, 2, "", ""]])
    result = InventoryBulkImportService.call(path)

    m = result.sync.inventory_movements.first
    assert_equal "exit", m.movement_type
    assert_equal @palmares, m.showroom
  ensure
    File.delete(path) if path && File.exist?(path)
  end

  test "matchea sala por código además de por nombre" do
    path = write_xlsx(HEADERS, [[@escazu.code, "", @product.base_code, @product.name, 1, "", ""]])
    result = InventoryBulkImportService.call(path)

    assert_equal @escazu, result.sync.inventory_movements.first.showroom
  ensure
    File.delete(path) if path && File.exist?(path)
  end

  test "código que matchea usa ese producto e ignora el nombre de la fila" do
    path = write_xlsx(HEADERS, [[@escazu.name, "", @product.base_code, "Nombre que no existe", 1, "", ""]])
    result = InventoryBulkImportService.call(path)

    assert_equal @product, result.sync.inventory_movements.first.product
  ensure
    File.delete(path) if path && File.exist?(path)
  end

  test "sin código, el nombre exacto resuelve el producto" do
    path = write_xlsx(HEADERS, [[@escazu.name, "", "", @product.name, 1, "", ""]])
    result = InventoryBulkImportService.call(path)

    assert_equal @product, result.sync.inventory_movements.first.product
  ensure
    File.delete(path) if path && File.exist?(path)
  end

  test "código que no matchea no cae a buscar por nombre" do
    path = write_xlsx(HEADERS, [[@escazu.name, "", "CODIGO-INEXISTENTE", @product.name, 1, "", ""]])
    result = InventoryBulkImportService.call(path)

    m = result.sync.inventory_movements.first
    assert_nil m.product_id
    assert_equal "unresolved", m.status
  ensure
    File.delete(path) if path && File.exist?(path)
  end

  test "código y nombre sin producto encontrado queda sin asignar pero la fila se conserva" do
    path = write_xlsx(HEADERS, [[@escazu.name, "", "NUEVO-001", "Producto nuevo", 1, "", ""]])
    result = InventoryBulkImportService.call(path)

    m = result.sync.inventory_movements.first
    assert_nil m.product_id
    assert_equal "unresolved", m.status
    assert_equal "Producto nuevo", m.product_name_raw
  ensure
    File.delete(path) if path && File.exist?(path)
  end

  test "sala que no existe descarta la fila y queda en import_errors" do
    path = write_xlsx(HEADERS, [["Sala que no existe", "", @product.base_code, @product.name, 1, "", ""]])
    result = InventoryBulkImportService.call(path)

    assert_equal 0, result.sync.inventory_movements.count
    assert_match "Sala que no existe", result.sync.import_errors.join
  ensure
    File.delete(path) if path && File.exist?(path)
  end

  test "cantidad inválida o cero descarta la fila" do
    path = write_xlsx(HEADERS, [[@escazu.name, "", @product.base_code, @product.name, 0, "", ""]])
    result = InventoryBulkImportService.call(path)

    assert_equal 0, result.sync.inventory_movements.count
    assert_match "cantidad", result.sync.import_errors.join.downcase
  ensure
    File.delete(path) if path && File.exist?(path)
  end

  test "fila sin ninguna sala indicada se descarta" do
    path = write_xlsx(HEADERS, [["", "", @product.base_code, @product.name, 1, "", ""]])
    result = InventoryBulkImportService.call(path)

    assert_equal 0, result.sync.inventory_movements.count
  ensure
    File.delete(path) if path && File.exist?(path)
  end

  test "fila sin código ni nombre de producto se descarta" do
    path = write_xlsx(HEADERS, [[@escazu.name, "", "", "", 1, "", ""]])
    result = InventoryBulkImportService.call(path)

    assert_equal 0, result.sync.inventory_movements.count
  ensure
    File.delete(path) if path && File.exist?(path)
  end

  test "archivo sin columnas requeridas reporta error sin crear sync" do
    path = write_xlsx(["Columna rara"], [["x"]])
    result = InventoryBulkImportService.call(path)

    assert_nil result.sync
    assert_match "Faltan columnas", result.file_errors.join
  ensure
    File.delete(path) if path && File.exist?(path)
  end

  test "archivo con encabezados válidos pero sin filas de datos no crea sync" do
    path = write_xlsx(HEADERS, [])
    result = InventoryBulkImportService.call(path)

    assert_nil result.sync
    assert result.file_errors.any?
  ensure
    File.delete(path) if path && File.exist?(path)
  end
end
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `bin/rails test test/services/inventory_bulk_import_service_test.rb`
Expected: FAIL — `NameError: uninitialized constant InventoryBulkImportService`

- [ ] **Step 3: Implement the service**

```ruby
# app/services/inventory_bulk_import_service.rb
class InventoryBulkImportService
  REQUIRED_HEADERS = %w[
    sala_receptora_entradas sala_emisora_salidas codigo_producto nombre_de_producto cantidad
  ].freeze

  Result = Struct.new(:sync, :file_errors, keyword_init: true)

  PendingMovement = Struct.new(
    :type, :showroom, :product, :product_name_raw, :quantity,
    :order_number, :delivery_date, :line_number, keyword_init: true
  )

  def self.call(file_path)
    new(file_path).import
  end

  def initialize(file_path)
    @file_path = file_path
    @row_errors = []
  end

  def import
    parsed = XlsxImportHelper.read_xlsx(@file_path)
    return failure(parsed[:errors]) if parsed[:errors].any?
    return failure(["El archivo no tiene filas."]) if parsed[:rows].empty?

    validation = CsvImportHelper.validate_headers(parsed[:rows].first.keys, REQUIRED_HEADERS)
    return failure([validation[:message]]) unless validation[:valid]

    pending = parsed[:rows].each_with_index.flat_map { |row, index| build_pending(row, index + 2) }

    sync = create_sync(pending)
    movements_created = save_movements(sync, pending)
    finalize_sync(sync, rows_count: parsed[:rows].size, created: movements_created)

    Result.new(sync: sync, file_errors: [])
  end

  private

  def failure(errors)
    Result.new(sync: nil, file_errors: errors)
  end

  def build_pending(row, line_number)
    code     = CsvImportHelper.normalize_string(row["codigo_producto"])
    name     = CsvImportHelper.normalize_string(row["nombre_de_producto"])
    quantity = CsvImportHelper.to_decimal(row["cantidad"])
    source_name      = CsvImportHelper.normalize_string(row["sala_emisora_salidas"])
    destination_name = CsvImportHelper.normalize_string(row["sala_receptora_entradas"])
    order_number     = CsvImportHelper.normalize_string(row["pedido"])
    delivery_date    = parse_date(row["fecha_del_movimiento"])

    if source_name.blank? && destination_name.blank?
      @row_errors << "Fila #{line_number}: debes indicar al menos una sala (receptora o emisora)."
      return []
    end

    if quantity.nil? || quantity <= 0
      @row_errors << "Fila #{line_number}: cantidad inválida."
      return []
    end

    if code.blank? && name.blank?
      @row_errors << "Fila #{line_number}: debes indicar código o nombre de producto."
      return []
    end

    source      = find_showroom(source_name)
    destination = find_showroom(destination_name)

    if source_name.present? && source.nil?
      @row_errors << "Fila #{line_number}: sala emisora '#{source_name}' no encontrada."
      return []
    end
    if destination_name.present? && destination.nil?
      @row_errors << "Fila #{line_number}: sala receptora '#{destination_name}' no encontrada."
      return []
    end

    product  = resolve_product(code, name)
    raw_name = name.presence || code

    entries = []
    entries << PendingMovement.new(type: "exit", showroom: source, product: product,
      product_name_raw: raw_name, quantity: quantity, order_number: order_number,
      delivery_date: delivery_date, line_number: line_number) if source
    entries << PendingMovement.new(type: "entry", showroom: destination, product: product,
      product_name_raw: raw_name, quantity: quantity, order_number: order_number,
      delivery_date: delivery_date, line_number: line_number) if destination
    entries
  end

  def find_showroom(identifier)
    return nil if identifier.blank?
    showrooms_by_identifier[identifier.downcase]
  end

  def showrooms_by_identifier
    @showrooms_by_identifier ||= Showroom.active.each_with_object({}) do |s, h|
      h[s.code.downcase] = s
      h[s.name.downcase] = s
    end
  end

  def resolve_product(code, name)
    if code.present?
      Product.find_by("LOWER(base_code) = ?", code.downcase)
    elsif name.present?
      Product.find_by("LOWER(name) = ?", name.downcase)
    end
  end

  def parse_date(value)
    return nil if value.blank?
    Date.parse(value)
  rescue ArgumentError, TypeError
    nil
  end

  def create_sync(pending)
    dates = pending.map(&:delivery_date).compact
    InventorySync.create!(
      kind: "bulk_upload",
      from_date: dates.min || Date.current,
      to_date:   dates.max || Date.current,
      status:    "pending_review",
      synced_at: Time.current
    )
  end

  def save_movements(sync, pending)
    pending.filter_map do |entry|
      movement = InventoryMovement.new(
        inventory_sync:    sync,
        movement_type:      entry.type,
        showroom:           entry.showroom,
        product:            entry.product,
        product_name_raw:   entry.product_name_raw,
        quantity:           entry.quantity,
        order_number:       entry.order_number.presence || "CARGA-#{sync.id}-F#{entry.line_number}",
        delivery_date:      entry.delivery_date || Date.current,
        source:             "manual",
        status:             entry.product ? "resolved" : "unresolved"
      )

      if movement.save
        movement
      else
        @row_errors << "Fila #{entry.line_number}: #{movement.errors.full_messages.join(', ')}"
        nil
      end
    end
  end

  def finalize_sync(sync, rows_count:, created:)
    sync.update!(
      deliveries_processed: rows_count,
      movements_count:      created.size,
      unresolved_count:     created.count { |m| m.status == "unresolved" },
      import_errors:        @row_errors
    )
  end
end
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `bin/rails test test/services/inventory_bulk_import_service_test.rb`
Expected: PASS (13 runs, 0 failures)

- [ ] **Step 5: Commit**

```bash
git add app/services/inventory_bulk_import_service.rb test/services/inventory_bulk_import_service_test.rb
git commit -m "Implementar InventoryBulkImportService: resolución de sala/producto por fila"
```

---

### Task 5: Transferencias, `Pedido`/`order_number` sintético y flag de stock

**Files:**
- Modify: `app/services/inventory_bulk_import_service.rb`
- Modify: `test/services/inventory_bulk_import_service_test.rb`

**Interfaces:**
- Consumes: `InventoryMovement.flag_if_stock_missing!` (Task 2).
- Produces: no new public interface — `InventoryBulkImportService.call` now also handles rows with both showroom columns filled (creating an `exit` + `entry` pair sharing one `order_number`) and flags insufficient-stock exits, on top of Task 4's behavior.

- [ ] **Step 1: Write the failing tests**

```ruby
# test/services/inventory_bulk_import_service_test.rb — add inside the class

  test "fila con ambas salas genera transferencia (exit + entry) con el mismo order_number" do
    path = write_xlsx(HEADERS, [[@escazu.name, @palmares.name, @product.base_code, @product.name, 1, "", ""]])
    result = InventoryBulkImportService.call(path)

    movements = result.sync.inventory_movements.to_a
    assert_equal 2, movements.size
    assert_equal 1, movements.count { |m| m.movement_type == "exit" && m.showroom == @palmares }
    assert_equal 1, movements.count { |m| m.movement_type == "entry" && m.showroom == @escazu }
    assert_equal movements[0].order_number, movements[1].order_number
  ensure
    File.delete(path) if path && File.exist?(path)
  end

  test "Pedido provisto se usa como order_number; vacío genera uno sintético por fila" do
    path = write_xlsx(HEADERS, [
      [@escazu.name, "", @product.base_code, @product.name, 1, "PED-1", ""],
      [@palmares.name, "", @product.base_code, @product.name, 1, "", ""]
    ])
    result = InventoryBulkImportService.call(path)

    movements = result.sync.inventory_movements.order(:id).to_a
    assert_equal "PED-1", movements[0].order_number
    assert_equal "CARGA-#{result.sync.id}-F3", movements[1].order_number
  ensure
    File.delete(path) if path && File.exist?(path)
  end

  test "salida con stock insuficiente queda marcada con flag stock_missing" do
    path = write_xlsx(HEADERS, [["", @palmares.name, @product.base_code, @product.name, 5, "", ""]])
    result = InventoryBulkImportService.call(path)

    m = result.sync.inventory_movements.first
    assert_equal "stock_missing", m.flag
    assert_match "Alerta automática", m.notes
  ensure
    File.delete(path) if path && File.exist?(path)
  end

  test "entry no se ve afectado por la validación de stock" do
    path = write_xlsx(HEADERS, [[@escazu.name, "", @product.base_code, @product.name, 999, "", ""]])
    result = InventoryBulkImportService.call(path)

    assert_nil result.sync.inventory_movements.first.flag
  ensure
    File.delete(path) if path && File.exist?(path)
  end

  test "deliveries_processed cuenta todas las filas del archivo, incluyendo descartadas" do
    path = write_xlsx(HEADERS, [
      [@escazu.name, "", @product.base_code, @product.name, 1, "", ""],
      ["Sala que no existe", "", @product.base_code, @product.name, 1, "", ""]
    ])
    result = InventoryBulkImportService.call(path)

    assert_equal 2, result.sync.deliveries_processed
    assert_equal 1, result.sync.movements_count
    assert_equal 1, result.sync.import_errors.size
  ensure
    File.delete(path) if path && File.exist?(path)
  end

  test "unresolved_count refleja movimientos sin producto asignado" do
    path = write_xlsx(HEADERS, [[@escazu.name, "", "SIN-MATCH", "Producto sin match", 1, "", ""]])
    result = InventoryBulkImportService.call(path)

    assert_equal 1, result.sync.unresolved_count
  ensure
    File.delete(path) if path && File.exist?(path)
  end
```

- [ ] **Step 2: Run tests to verify the new ones fail**

Run: `bin/rails test test/services/inventory_bulk_import_service_test.rb`
Expected: 4 of the 6 new tests FAIL — the transfer/`Pedido` tests already pass from Task 4's `save_movements` (it already builds the synthetic `order_number` and handles two pending entries sharing `line_number`); the **stock flag** tests fail because `flag_if_stock_missing!` is never called yet.

- [ ] **Step 3: Call the stock-flag check when saving exit movements**

In `app/services/inventory_bulk_import_service.rb`, inside `save_movements`, right before `if movement.save`:

```ruby
      InventoryMovement.flag_if_stock_missing!(movement) if movement.movement_type == "exit"

      if movement.save
```

- [ ] **Step 4: Run tests to verify they all pass**

Run: `bin/rails test test/services/inventory_bulk_import_service_test.rb`
Expected: PASS (19 runs, 0 failures)

- [ ] **Step 5: Commit**

```bash
git add app/services/inventory_bulk_import_service.rb test/services/inventory_bulk_import_service_test.rb
git commit -m "Aplicar flag_if_stock_missing! a las salidas generadas por carga masiva"
```

---

### Task 6: `InventoryBulkImportTemplateService`

**Files:**
- Create: `app/services/inventory_bulk_import_template_service.rb`
- Test: `test/services/inventory_bulk_import_template_service_test.rb` (new file)

**Interfaces:**
- Consumes: `Showroom.active`, `caxlsx` (`Axlsx::Package`).
- Produces: `InventoryBulkImportTemplateService.call` → binary `String` (xlsx file content), with sheet "Carga" (headers + one example row) and sheet "Salas válidas" (code + name of every active showroom).

- [ ] **Step 1: Write the failing test**

```ruby
# test/services/inventory_bulk_import_template_service_test.rb
require "test_helper"
require "roo"

class InventoryBulkImportTemplateServiceTest < ActiveSupport::TestCase
  test "genera un xlsx con los encabezados esperados y las salas activas" do
    inactive = Showroom.create!(name: "Bodega vieja", code: "BV", active: false)

    content = InventoryBulkImportTemplateService.call

    path = Rails.root.join("tmp", "test_template_#{SecureRandom.hex(4)}.xlsx").to_s
    File.binwrite(path, content)

    carga = Roo::Excelx.new(path).sheet(0)
    assert_equal [
      "Sala receptora (Entradas)", "Sala emisora (Salidas)",
      "Código producto", "Nombre de producto", "Cantidad", "Pedido", "Fecha del movimiento"
    ], carga.row(1)

    salas = Roo::Excelx.new(path).sheet(1)
    codes = (2..salas.last_row).map { |i| salas.row(i).first }
    assert_includes codes, showrooms(:palmares).code
    assert_not_includes codes, inactive.code
  ensure
    File.delete(path) if path && File.exist?(path)
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bin/rails test test/services/inventory_bulk_import_template_service_test.rb`
Expected: FAIL — `NameError: uninitialized constant InventoryBulkImportTemplateService`

- [ ] **Step 3: Implement the service**

```ruby
# app/services/inventory_bulk_import_template_service.rb
require "caxlsx"

class InventoryBulkImportTemplateService
  HEADERS = [
    "Sala receptora (Entradas)", "Sala emisora (Salidas)",
    "Código producto", "Nombre de producto", "Cantidad", "Pedido", "Fecha del movimiento"
  ].freeze

  def self.call
    new.build
  end

  def build
    package = Axlsx::Package.new
    add_carga_sheet(package.workbook)
    add_salas_sheet(package.workbook)
    package.to_stream.read
  end

  private

  def add_carga_sheet(workbook)
    workbook.add_worksheet(name: "Carga") do |sheet|
      header_style = sheet.styles.add_style(b: true, bg_color: "DDEBF7")
      sheet.add_row HEADERS, style: header_style
      sheet.add_row ["Sala Escazú", "Sala Palmares", "SOF-001", "Sofá 3 puestos", 2, "", Date.current]
    end
  end

  def add_salas_sheet(workbook)
    workbook.add_worksheet(name: "Salas válidas") do |sheet|
      header_style = sheet.styles.add_style(b: true, bg_color: "DDEBF7")
      sheet.add_row ["Código", "Nombre"], style: header_style
      Showroom.active.order(:name).each { |s| sheet.add_row [s.code, s.name] }
    end
  end
end
```

- [ ] **Step 4: Run test to verify it passes**

Run: `bin/rails test test/services/inventory_bulk_import_template_service_test.rb`
Expected: PASS (1 run, 0 failures)

- [ ] **Step 5: Commit**

```bash
git add app/services/inventory_bulk_import_template_service.rb test/services/inventory_bulk_import_template_service_test.rb
git commit -m "Implementar InventoryBulkImportTemplateService para la plantilla descargable"
```

---

### Task 7: Rutas, `Inventory::BulkImportsController`, vista de subida y acceso desde el dashboard

**Files:**
- Modify: `config/routes.rb`
- Create: `app/controllers/inventory/bulk_imports_controller.rb`
- Create: `app/views/inventory/bulk_imports/new.html.erb`
- Modify: `app/views/inventory/dashboard/index.html.erb`
- Test: `test/controllers/inventory_bulk_imports_controller_test.rb` (new file)

**Interfaces:**
- Consumes: `InventoryBulkImportService.call(path)` (Task 5), `InventoryBulkImportTemplateService.call` (Task 6).
- Produces: routes `new_inventory_bulk_import_path` (GET), `inventory_bulk_imports_path` (POST), `inventory_bulk_import_template_path` (GET).

- [ ] **Step 1: Write the failing tests**

```ruby
# test/controllers/inventory_bulk_imports_controller_test.rb
require "test_helper"
require "caxlsx"

class InventoryBulkImportsControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    sign_in users(:admin)
    @escazu  = showrooms(:escazu)
    @product = products(:one)
  end

  def write_xlsx(headers, rows)
    path = Rails.root.join("tmp", "test_bulk_controller_#{SecureRandom.hex(4)}.xlsx").to_s
    Axlsx::Package.new do |p|
      p.workbook.add_worksheet(name: "Carga") do |sheet|
        sheet.add_row headers if headers
        rows.each { |r| sheet.add_row r }
      end
    end.serialize(path)
    path
  end

  test "should get new" do
    get new_inventory_bulk_import_url
    assert_response :success
  end

  test "descarga la plantilla en formato xlsx" do
    get inventory_bulk_import_template_url
    assert_response :success
    assert_equal "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet", @response.media_type
  end

  test "procesa un archivo válido y redirige a la revisión del sync creado" do
    headers = [
      "Sala receptora (Entradas)", "Sala emisora (Salidas)",
      "Código producto", "Nombre de producto", "Cantidad", "Pedido", "Fecha del movimiento"
    ]
    path = write_xlsx(headers, [[@escazu.name, "", @product.base_code, @product.name, 3, "", ""]])

    assert_difference("InventorySync.count", 1) do
      assert_difference("InventoryMovement.count", 1) do
        post inventory_bulk_imports_url, params: {
          file: Rack::Test::UploadedFile.new(path, "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet")
        }
      end
    end

    sync = InventorySync.order(:created_at).last
    assert_equal "bulk_upload", sync.kind
    assert_redirected_to inventory_sync_path(sync)
  ensure
    File.delete(path) if path && File.exist?(path)
  end

  test "archivo sin columnas requeridas vuelve al formulario con error y sin crear sync" do
    path = write_xlsx(["Columna rara"], [["x"]])

    assert_no_difference("InventorySync.count") do
      post inventory_bulk_imports_url, params: {
        file: Rack::Test::UploadedFile.new(path, "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet")
      }
    end

    assert_redirected_to new_inventory_bulk_import_path
  ensure
    File.delete(path) if path && File.exist?(path)
  end

  test "sin archivo adjunto vuelve al formulario con error" do
    post inventory_bulk_imports_url, params: {}
    assert_redirected_to new_inventory_bulk_import_path
  end
end
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `bin/rails test test/controllers/inventory_bulk_imports_controller_test.rb`
Expected: FAIL — routing error (`undefined method 'new_inventory_bulk_import_url'`)

- [ ] **Step 3: Add the routes**

In `config/routes.rb`, inside the `scope "inventory", module: "inventory" do` block, right after the `initial_stock` routes (after line `post "initial_stock", ...`):

```ruby
    get  "bulk_imports/new",      to: "bulk_imports#new",      as: :new_inventory_bulk_import
    post "bulk_imports",          to: "bulk_imports#create",   as: :inventory_bulk_imports
    get  "bulk_imports/template", to: "bulk_imports#template", as: :inventory_bulk_import_template
```

- [ ] **Step 4: Implement the controller**

```ruby
# app/controllers/inventory/bulk_imports_controller.rb
class Inventory::BulkImportsController < Inventory::BaseController
  def new
  end

  def create
    unless params[:file].present?
      redirect_to new_inventory_bulk_import_path, alert: "Selecciona un archivo .xlsx."
      return
    end

    tmp_path = Rails.root.join("tmp", "bulk_import_#{Time.now.to_i}_#{SecureRandom.hex(4)}.xlsx")
    FileUtils.cp(params[:file].tempfile.path, tmp_path)

    result = InventoryBulkImportService.call(tmp_path.to_s)

    if result.sync
      notice = "Carga procesada: #{result.sync.movements_count} movimiento(s) generado(s)."
      notice += " #{result.sync.import_errors.size} fila(s) con error fueron omitidas." if result.sync.import_errors.any?
      redirect_to inventory_sync_path(result.sync), notice: notice
    else
      redirect_to new_inventory_bulk_import_path, alert: result.file_errors.join("; ")
    end
  ensure
    File.delete(tmp_path) if tmp_path && File.exist?(tmp_path)
  end

  def template
    send_data InventoryBulkImportTemplateService.call,
      filename: "plantilla_carga_masiva_inventario.xlsx",
      type: "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
  end
end
```

- [ ] **Step 5: Add the upload view**

```erb
<%# app/views/inventory/bulk_imports/new.html.erb %>
<div class="d-flex justify-content-between align-items-center mb-4 flex-wrap gap-3">
  <div>
    <h1 class="fw-bold mb-0 fs-4"><i class="bi bi-file-earmark-spreadsheet me-2 text-primary"></i>Carga masiva de inventario</h1>
    <p class="text-muted small mb-0">Sube un Excel con movimientos de entrada, salida o transferencia entre salas.</p>
  </div>
  <%= link_to inventory_bulk_import_template_path, class: "btn btn-outline-secondary btn-sm" do %>
    <i class="bi bi-download me-1"></i>Descargar plantilla
  <% end %>
</div>

<div class="card border-0 shadow-sm">
  <div class="card-body">
    <%= form_with url: inventory_bulk_imports_path, method: :post, multipart: true do %>
      <div class="mb-3">
        <label class="form-label small fw-semibold">Archivo Excel (.xlsx) <span class="text-danger">*</span></label>
        <%= file_field_tag :file, accept: ".xlsx", class: "form-control", required: true %>
      </div>
      <div class="form-text mb-3">
        Columnas esperadas: Sala receptora (Entradas), Sala emisora (Salidas), Código producto,
        Nombre de producto, Cantidad, Pedido (opcional), Fecha del movimiento (opcional).
      </div>
      <div class="d-flex justify-content-end gap-2">
        <%= link_to "Cancelar", inventory_path, class: "btn btn-outline-secondary" %>
        <button type="submit" class="btn btn-primary fw-semibold">
          <i class="bi bi-cloud-upload me-1"></i>Procesar archivo
        </button>
      </div>
    <% end %>
  </div>
</div>
```

- [ ] **Step 6: Add the dashboard entry point**

In `app/views/inventory/dashboard/index.html.erb`, right after the existing "Sincronizar" button (the `<button ... data-bs-target="#syncForm">` block near the top):

```erb
    <%= link_to new_inventory_bulk_import_path, class: "btn btn-outline-primary btn-sm" do %>
      <i class="bi bi-file-earmark-spreadsheet me-1"></i>Carga masiva (Excel)
    <% end %>
```

- [ ] **Step 7: Run tests to verify they pass**

Run: `bin/rails test test/controllers/inventory_bulk_imports_controller_test.rb`
Expected: PASS (5 runs, 0 failures)

- [ ] **Step 8: Commit**

```bash
git add config/routes.rb app/controllers/inventory/bulk_imports_controller.rb app/views/inventory/bulk_imports/new.html.erb app/views/inventory/dashboard/index.html.erb test/controllers/inventory_bulk_imports_controller_test.rb
git commit -m "Agregar Inventory::BulkImportsController, vista de subida y acceso desde el dashboard"
```

---

### Task 8: Copy condicional y `import_errors` en la pantalla de revisión

**Files:**
- Modify: `app/views/inventory/syncs/show.html.erb`
- Test: `test/controllers/inventory_syncs_controller_test.rb` (new file)

**Interfaces:**
- Consumes: `InventorySync#bulk_upload?` (Task 1), `InventorySync#import_errors` (Task 1).
- Produces: no new interface — the existing `Inventory::SyncsController#show` route now renders sync-kind-appropriate copy and surfaces `import_errors`.

- [ ] **Step 1: Write the failing tests**

```ruby
# test/controllers/inventory_syncs_controller_test.rb
require "test_helper"

class InventorySyncsControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    sign_in users(:admin)
  end

  test "sync de tipo logistics_sync muestra el título de sincronización" do
    sync = InventorySync.create!(from_date: Date.current, to_date: Date.current, status: "pending_review")

    get inventory_sync_url(sync)

    assert_response :success
    assert_match "Revisión de sincronización", @response.body
  end

  test "sync de tipo bulk_upload muestra el título de carga masiva y sus import_errors" do
    sync = InventorySync.create!(
      from_date: Date.current, to_date: Date.current, status: "pending_review",
      kind: "bulk_upload", deliveries_processed: 3, movements_count: 2,
      import_errors: ["Fila 4: sala emisora 'X' no encontrada."]
    )

    get inventory_sync_url(sync)

    assert_response :success
    assert_match "Revisión de carga masiva", @response.body
    assert_match "filas procesadas", @response.body
    assert_match "Fila 4: sala emisora", @response.body
  end
end
```

- [ ] **Step 2: Run tests to verify the bulk_upload one fails**

Run: `bin/rails test test/controllers/inventory_syncs_controller_test.rb`
Expected: the `logistics_sync` test PASSes already (no view changes needed there); the `bulk_upload` test FAILs — body still says "Revisión de sincronización" and "entregas", and never renders `import_errors`.

- [ ] **Step 3: Update the view**

In `app/views/inventory/syncs/show.html.erb`, replace the header block (lines computing/rendering the breadcrumb, `<h1>`, and the date/count line):

```erb
<%# ── HEADER ── %>
<% title      = @sync.bulk_upload? ? "Revisión de carga masiva" : "Revisión de sincronización" %>
<% unit_label = @sync.bulk_upload? ? "filas procesadas" : "entregas" %>
<% icon       = @sync.bulk_upload? ? "bi-file-earmark-spreadsheet" : "bi-arrow-repeat" %>
<div class="d-flex justify-content-between align-items-start mb-4 flex-wrap gap-3">
  <div>
    <nav aria-label="breadcrumb" class="mb-1">
      <ol class="breadcrumb mb-0 small">
        <li class="breadcrumb-item"><%= link_to "Inventario", inventory_path %></li>
        <li class="breadcrumb-item active"><%= title %></li>
      </ol>
    </nav>
    <h1 class="fw-bold mb-0 fs-4"><i class="bi <%= icon %> me-2 text-primary"></i><%= title %></h1>
    <p class="text-muted small mb-0">
      <%= @sync.from_date.strftime("%d/%m/%Y") %> – <%= @sync.to_date.strftime("%d/%m/%Y") %>
      &nbsp;·&nbsp; <%= @sync.deliveries_processed %> <%= unit_label %>
      &nbsp;·&nbsp; <strong><%= @sync.movements_count %></strong> movimientos
    </p>
  </div>
```

(Leave the rest of that header `<div>` — the "Confirmar y aplicar"/"Eliminar" buttons — untouched.)

Then, right after the closing `</div>` of that header block and before the `<%# ── KPI CARDS ── %>` comment, add:

```erb
<% if @sync.import_errors.present? %>
  <div class="alert alert-warning border-0 shadow-sm mb-4">
    <i class="bi bi-exclamation-triangle me-2"></i>
    <strong><%= @sync.import_errors.size %> fila(s)</strong> del archivo no se pudieron procesar y fueron omitidas:
    <ul class="mb-0 mt-2 small">
      <% @sync.import_errors.each do |err| %>
        <li><%= err %></li>
      <% end %>
    </ul>
  </div>
<% end %>
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `bin/rails test test/controllers/inventory_syncs_controller_test.rb`
Expected: PASS (2 runs, 0 failures)

- [ ] **Step 5: Run the full inventory test suite for a final regression check**

Run: `bin/rails test test/models/inventory_sync_test.rb test/models/inventory_movement_test.rb test/controllers/inventory_exits_controller_test.rb test/services/inventory_classifier_test.rb test/services/inventory_resolver_test.rb test/helpers/xlsx_import_helper_test.rb test/services/inventory_bulk_import_service_test.rb test/services/inventory_bulk_import_template_service_test.rb test/controllers/inventory_bulk_imports_controller_test.rb test/controllers/inventory_syncs_controller_test.rb`
Expected: PASS, 0 failures, 0 errors.

- [ ] **Step 6: Commit**

```bash
git add app/views/inventory/syncs/show.html.erb test/controllers/inventory_syncs_controller_test.rb
git commit -m "Mostrar copy condicional e import_errors en la revisión de carga masiva"
```

---

## Out of scope (documented, not implemented here)

- `.csv`/`.ods` support for upload or template.
- Deduplication against previously-uploaded rows (re-uploading the same file creates duplicate movements; resolved by hand in the review screen like any other error).
- Auto-resolving an unmatched showroom from the review screen (it's a hard error, never enters the draft).
- Pre-filling the existing "crear producto" modal with the row's código/nombre for unresolved products — the row still shows `product_name_raw` so the user has what they need to create it manually, same as today's synced-sync flow.
