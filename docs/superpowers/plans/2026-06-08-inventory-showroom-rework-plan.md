# Rework del módulo de inventario de salas (showrooms) — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the regex-based showroom inventory classifier with a `Showroom`-entity-driven design that uses the Logistics API's structured `source_showroom`/`destination_showroom` fields, add a manual-exit + discrepancy-alert workflow, and fix the `ProductDecoder` performance bottleneck via per-run memoization.

**Architecture:** New `Showroom` ActiveRecord model (CRUD-managed, JSON-array config fields serialized like `CodeSetting`) replaces the `SP/SE/SG` string enum on `InventoryMovement` (`belongs_to :showroom`). `InventoryClassifier` evaluates two independent rules per delivery (inter-sala movement via structured showroom data; main-sala restock via configurable order-number prefixes) and returns `Showroom` records instead of string codes. `InventoryResolver` is refactored to process a whole sync's deliveries in one instantiation so `ProductDecoder.decode` is memoized per unique `product_name` for the entire run. New `InventoryExitsController`/`InventoryAlertsController` implement the manual-exit + `flag: "stock_missing"` discrepancy flow described in the spec.

**Tech Stack:** Rails 7.2, Minitest + fixtures, Stimulus.js, Bootstrap 5, SQLite, `serialize coder: JSON`, Devise test integration helpers.

**Reference spec:** `docs/superpowers/specs/2026-06-08-inventory-showroom-rework-design.md` (committed as `5e14f60`). Every task below implements a section of that spec — quote it if you need the "why."

---

## Before you start

Run the full inventory-related test suite once to capture the baseline (some pre-existing controller tests are known-broken and unrelated — `families_controller_test.rb` / `variant_types_controller_test.rb` fail with redirects to `/users/sign_in` because no admin fixture + `Devise::Test::IntegrationHelpers` exist globally; **do not try to fix those**, they are out of scope):

```bash
bin/rails test test/services/inventory_classifier_test.rb test/models/logistics_sync_cursor_test.rb
```

Expected: the classifier tests pass today (they test the old regex-fallback behavior — Task 6 will replace this whole file).

---

## Task 1: `Showroom` migration

**Files:**
- Create: `db/migrate/20260608130000_create_showrooms.rb`

- [ ] **Step 1: Write the migration**

```ruby
class CreateShowrooms < ActiveRecord::Migration[7.2]
  def change
    create_table :showrooms do |t|
      t.string  :name, null: false
      t.string  :code, null: false
      t.boolean :is_main, default: false, null: false
      t.text    :order_number_prefixes
      t.text    :order_number_keywords
      t.text    :inter_sala_keywords
      t.text    :product_keywords
      t.boolean :active, default: true, null: false
      t.timestamps
    end

    add_index :showrooms, :code, unique: true
    add_index :showrooms, :is_main
    add_index :showrooms, :active
  end
end
```

- [ ] **Step 2: Run the migration**

```bash
bin/rails db:migrate
```

Expected: `== 20260608130000 CreateShowrooms: migrated`, and `db/schema.rb` now has a `create_table "showrooms"` block with the columns above plus the indexes.

- [ ] **Step 3: Commit**

```bash
git add db/migrate/20260608130000_create_showrooms.rb db/schema.rb
git commit -m "Agregar tabla showrooms para modelar salas como entidad real"
```

---

## Task 2: `Showroom` model + fixtures + tests

**Files:**
- Create: `app/models/showroom.rb`
- Create: `test/fixtures/showrooms.yml`
- Create: `test/models/showroom_test.rb`

- [ ] **Step 1: Write the fixtures (needed by the model tests and every later spec that touches showrooms)**

```yaml
# test/fixtures/showrooms.yml
palmares:
  name: Sala Palmares
  code: SP
  is_main: true
  active: true
  order_number_prefixes: '["2","3"]'
  order_number_keywords: '[]'
  inter_sala_keywords: '[]'
  product_keywords: '[]'

escazu:
  name: Sala Escazú
  code: SE
  is_main: false
  active: true
  order_number_prefixes: '["2","3"]'
  order_number_keywords: '[]'
  inter_sala_keywords: '[]'
  product_keywords: '[]'

guanacaste:
  name: Sala Guanacaste
  code: SG
  is_main: false
  active: true
  order_number_prefixes: '["2","3"]'
  order_number_keywords: '[]'
  inter_sala_keywords: '[]'
  product_keywords: '[]'
```

(The serialized columns are `text` — fixtures bypass the model layer and insert raw column values, so we write the literal JSON strings, exactly as they'll be stored on disk.)

- [ ] **Step 2: Write the failing model test**

```ruby
# test/models/showroom_test.rb
require "test_helper"

class ShowroomTest < ActiveSupport::TestCase
  test "valid with name and code, normalizes code to uppercase" do
    showroom = Showroom.new(name: "Sala Test", code: "st")
    assert showroom.valid?
    assert_equal "ST", showroom.code
  end

  test "requires name and code" do
    showroom = Showroom.new
    assert_not showroom.valid?
    assert_includes showroom.errors[:name], "can't be blank"
    assert_includes showroom.errors[:code], "can't be blank"
  end

  test "code must be unique case-insensitively" do
    Showroom.create!(name: "Sala Palmares Dup", code: "spd")
    dup = Showroom.new(name: "Otra", code: "SPD")
    assert_not dup.valid?
    assert_includes dup.errors[:code], "has already been taken"
  end

  test "activating is_main demotes any other main showroom" do
    palmares = showrooms(:palmares)
    escazu   = showrooms(:escazu)
    assert palmares.is_main?

    escazu.update!(is_main: true)

    assert escazu.reload.is_main?
    assert_not palmares.reload.is_main?
  end

  test "stores and reads JSON array fields through the *_array helpers" do
    showroom = Showroom.create!(
      name: "Sala Helper", code: "SH",
      order_number_prefixes: ["2", "3"],
      order_number_keywords: ["ESCAZU", " guanacaste "]
    )

    assert_equal ["2", "3"], showroom.reload.order_number_prefixes_array
    assert_equal ["ESCAZU", "guanacaste"], showroom.order_number_keywords_array
  end

  test "array helpers default to an empty array when blank" do
    showroom = Showroom.create!(name: "Sala Vacía", code: "SV")
    assert_equal [], showroom.inter_sala_keywords_array
    assert_equal [], showroom.product_keywords_array
  end
end
```

- [ ] **Step 3: Run it to confirm it fails**

```bash
bin/rails test test/models/showroom_test.rb
```

Expected: `Error: uninitialized constant Showroom` (or fixture load errors referencing a missing `showrooms` table/model).

- [ ] **Step 4: Write the model**

```ruby
# app/models/showroom.rb
class Showroom < ApplicationRecord
  ARRAY_ATTRIBUTES = %w[
    order_number_prefixes order_number_keywords inter_sala_keywords product_keywords
  ].freeze

  ARRAY_ATTRIBUTES.each { |attr| serialize attr, coder: JSON }

  has_many :inventory_movements, dependent: :restrict_with_error

  validates :name, presence: true
  validates :code, presence: true, uniqueness: { case_sensitive: false }

  before_validation :normalize_code
  before_save :demote_other_mains, if: -> { is_main? && (new_record? || is_main_changed?) }

  scope :active, -> { where(active: true) }

  ARRAY_ATTRIBUTES.each do |attr|
    define_method("#{attr}_array") { array_attribute(attr) }
  end

  private

  def normalize_code
    self.code = code.to_s.strip.upcase
  end

  def demote_other_mains
    Showroom.where(is_main: true).where.not(id: id).update_all(is_main: false)
  end

  def array_attribute(attr_name)
    raw = read_attribute_before_type_cast(attr_name)

    parsed =
      case raw
      when nil
        []
      when Array
        raw
      when String
        begin
          JSON.parse(raw)
        rescue JSON::ParserError
          [raw]
        end
      else
        Array(raw)
      end

    Array(parsed).map(&:to_s).map(&:strip).reject(&:blank?)
  end
end
```

- [ ] **Step 5: Run the test again to confirm it passes**

```bash
bin/rails test test/models/showroom_test.rb
```

Expected: `5 runs, ... 0 failures, 0 errors`

- [ ] **Step 6: Commit**

```bash
git add app/models/showroom.rb test/fixtures/showrooms.yml test/models/showroom_test.rb
git commit -m "Agregar modelo Showroom con catálogos JSON y unicidad de sala principal"
```

---

## Task 3: `Showroom` CRUD (routes, controller, views, tag-list Stimulus controller, tests)

**Files:**
- Modify: `config/routes.rb`
- Create: `app/controllers/showrooms_controller.rb`
- Create: `app/javascript/controllers/tag_list_controller.js`
- Create: `app/views/showrooms/index.html.erb`
- Create: `app/views/showrooms/_form.html.erb`
- Create: `app/views/showrooms/new.html.erb`
- Create: `app/views/showrooms/edit.html.erb`
- Modify: `test/fixtures/users.yml`
- Create: `test/controllers/showrooms_controller_test.rb`

- [ ] **Step 1: Add an `admin` fixture (needed by every controller test we write in this plan)**

In `test/fixtures/users.yml`, add a third entry without touching `one`/`two` (the existing broken `families`/`variant_types` controller tests don't use `sign_in`, so this is purely additive):

```yaml
admin:
  email: admin_test@example.com
  encrypted_password: x
  role: admin
```

- [ ] **Step 2: Add routes**

In `config/routes.rb`, right after the `resources :families ... end` block (around line 56), add:

```ruby
  # Salas de exhibición (showrooms): catálogo y reglas de clasificación de inventario
  resources :showrooms
```

- [ ] **Step 3: Write the generalized tag-list Stimulus controller**

This generalizes `app/javascript/controllers/stock_options_controller.js` so any JSON-array field can use it via `data-tag-list-name-value`/`data-tag-list-placeholder-value`.

```javascript
// app/javascript/controllers/tag_list_controller.js
import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["list", "item"];
  static values = { name: String, placeholder: String };

  add() {
    const item = document.createElement("div");
    item.className = "input-group";
    item.dataset.tagListTarget = "item";
    item.innerHTML = `
      <input type="text"
             name="${this.nameValue}"
             class="form-control"
             placeholder="${this.placeholderValue}">
      <button type="button"
              class="btn btn-outline-danger"
              data-action="click->tag-list#remove">
        <i class="bi bi-trash"></i>
      </button>`;
    this.listTarget.appendChild(item);
    item.querySelector("input").focus();
  }

  remove(event) {
    const item = event.currentTarget.closest("[data-tag-list-target='item']");
    if (this.itemTargets.length > 1) {
      item.remove();
    } else {
      item.querySelector("input").value = "";
    }
  }
}
```

- [ ] **Step 4: Write the controller**

```ruby
# app/controllers/showrooms_controller.rb
class ShowroomsController < ApplicationController
  before_action :authenticate_user!
  before_action :authorize_admin!
  before_action :set_showroom, only: %i[edit update destroy]

  def index
    @showrooms = Showroom.order(is_main: :desc, name: :asc)
  end

  def new
    @showroom = Showroom.new(active: true)
  end

  def edit
  end

  def create
    @showroom = Showroom.new(showroom_params)
    if @showroom.save
      redirect_to showrooms_path, notice: "Sala creada exitosamente."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def update
    if @showroom.update(showroom_params)
      redirect_to showrooms_path, notice: "Sala actualizada exitosamente."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    if @showroom.destroy
      redirect_to showrooms_path, notice: "Sala eliminada."
    else
      redirect_to showrooms_path, alert: @showroom.errors.full_messages.to_sentence
    end
  end

  private

  def set_showroom
    @showroom = Showroom.find(params[:id])
  end

  def showroom_params
    params.require(:showroom).permit(
      :name, :code, :is_main, :active,
      order_number_prefixes: [],
      order_number_keywords: [],
      inter_sala_keywords: [],
      product_keywords: []
    )
  end
end
```

- [ ] **Step 5: Write the form partial**

```erb
<%# app/views/showrooms/_form.html.erb %>
<%= form_with(model: showroom) do |f| %>
  <% if showroom.errors.any? %>
    <div class="alert alert-danger mb-4">
      <ul class="mb-0 ps-3">
        <% showroom.errors.full_messages.each do |msg| %>
          <li><%= msg %></li>
        <% end %>
      </ul>
    </div>
  <% end %>

  <div class="row g-4">
    <div class="col-md-6">
      <%= f.label :name, "Nombre", class: "form-label fw-bold" %>
      <%= f.text_field :name, class: "form-control", placeholder: "Ej: Sala Palmares" %>
    </div>
    <div class="col-md-6">
      <%= f.label :code, "Código", class: "form-label fw-bold" %>
      <%= f.text_field :code, class: "form-control text-uppercase", placeholder: "Ej: SP" %>
      <div class="form-text">Debe coincidir con el código de showroom de la API de Rutas Nalakalu.</div>
    </div>
    <div class="col-md-6">
      <div class="form-check form-switch">
        <%= f.check_box :is_main, class: "form-check-input", role: "switch" %>
        <%= f.label :is_main, "Es la sala principal", class: "form-check-label fw-bold" %>
      </div>
      <div class="form-text">Solo una sala puede ser principal. Activar esta marcará automáticamente las demás como no principales.</div>
    </div>
    <div class="col-md-6">
      <div class="form-check form-switch">
        <%= f.check_box :active, class: "form-check-input", role: "switch" %>
        <%= f.label :active, "Sala activa", class: "form-check-label fw-bold" %>
      </div>
    </div>

    <div class="col-12 mt-2">
      <h5 class="text-primary border-bottom pb-2 mb-3">Reglas activas</h5>
    </div>
    <div class="col-12"
         data-controller="tag-list"
         data-tag-list-name-value="showroom[order_number_prefixes][]"
         data-tag-list-placeholder-value="Ej: 2">
      <label class="form-label fw-bold">Prefijos de pedido para reabastecimiento</label>
      <div class="form-text mb-3">
        Cuando esta sala es la <strong>principal</strong>, los pedidos cuyo número empiece con
        alguno de estos prefijos generan automáticamente una entrada de inventario hacia ella.
      </div>
      <div data-tag-list-target="list" class="d-flex flex-column gap-2 mb-3">
        <% (showroom.order_number_prefixes_array.presence || [""]).each do |prefix| %>
          <div class="input-group" data-tag-list-target="item">
            <input type="text" name="showroom[order_number_prefixes][]" value="<%= prefix %>"
                   class="form-control" placeholder="Ej: 2">
            <button type="button" class="btn btn-outline-danger" data-action="click->tag-list#remove">
              <i class="bi bi-trash"></i>
            </button>
          </div>
        <% end %>
      </div>
      <button type="button" class="btn btn-outline-secondary btn-sm" data-action="click->tag-list#add">
        <i class="bi bi-plus-circle me-1"></i>Agregar prefijo
      </button>
    </div>

    <div class="col-12 mt-3">
      <button class="btn btn-link text-decoration-none p-0" type="button"
              data-bs-toggle="collapse" data-bs-target="#advancedRules">
        <i class="bi bi-chevron-down me-1"></i>Reglas avanzadas (próximamente)
      </button>
      <div class="collapse mt-3" id="advancedRules">
        <div class="alert alert-secondary small mb-3">
          Estos catálogos se almacenan y quedan disponibles para futuras reglas de
          clasificación, pero el clasificador actual <strong>no los utiliza todavía</strong>.
        </div>
        <div class="row g-4">
          <div class="col-md-4"
               data-controller="tag-list"
               data-tag-list-name-value="showroom[order_number_keywords][]"
               data-tag-list-placeholder-value="Ej: ESCAZU">
            <label class="form-label fw-bold small">Palabras clave de pedido</label>
            <div data-tag-list-target="list" class="d-flex flex-column gap-2 mb-2">
              <% (showroom.order_number_keywords_array.presence || [""]).each do |kw| %>
                <div class="input-group input-group-sm" data-tag-list-target="item">
                  <input type="text" name="showroom[order_number_keywords][]" value="<%= kw %>"
                         class="form-control" placeholder="Ej: ESCAZU">
                  <button type="button" class="btn btn-outline-danger" data-action="click->tag-list#remove">
                    <i class="bi bi-trash"></i>
                  </button>
                </div>
              <% end %>
            </div>
            <button type="button" class="btn btn-outline-secondary btn-sm" data-action="click->tag-list#add">
              <i class="bi bi-plus-circle me-1"></i>Agregar
            </button>
          </div>
          <div class="col-md-4"
               data-controller="tag-list"
               data-tag-list-name-value="showroom[inter_sala_keywords][]"
               data-tag-list-placeholder-value="Ej: ENTRE SALA">
            <label class="form-label fw-bold small">Palabras clave entre-sala</label>
            <div data-tag-list-target="list" class="d-flex flex-column gap-2 mb-2">
              <% (showroom.inter_sala_keywords_array.presence || [""]).each do |kw| %>
                <div class="input-group input-group-sm" data-tag-list-target="item">
                  <input type="text" name="showroom[inter_sala_keywords][]" value="<%= kw %>"
                         class="form-control" placeholder="Ej: ENTRE SALA">
                  <button type="button" class="btn btn-outline-danger" data-action="click->tag-list#remove">
                    <i class="bi bi-trash"></i>
                  </button>
                </div>
              <% end %>
            </div>
            <button type="button" class="btn btn-outline-secondary btn-sm" data-action="click->tag-list#add">
              <i class="bi bi-plus-circle me-1"></i>Agregar
            </button>
          </div>
          <div class="col-md-4"
               data-controller="tag-list"
               data-tag-list-name-value="showroom[product_keywords][]"
               data-tag-list-placeholder-value="Ej: SOFA">
            <label class="form-label fw-bold small">Palabras clave de producto</label>
            <div data-tag-list-target="list" class="d-flex flex-column gap-2 mb-2">
              <% (showroom.product_keywords_array.presence || [""]).each do |kw| %>
                <div class="input-group input-group-sm" data-tag-list-target="item">
                  <input type="text" name="showroom[product_keywords][]" value="<%= kw %>"
                         class="form-control" placeholder="Ej: SOFA">
                  <button type="button" class="btn btn-outline-danger" data-action="click->tag-list#remove">
                    <i class="bi bi-trash"></i>
                  </button>
                </div>
              <% end %>
            </div>
            <button type="button" class="btn btn-outline-secondary btn-sm" data-action="click->tag-list#add">
              <i class="bi bi-plus-circle me-1"></i>Agregar
            </button>
          </div>
        </div>
      </div>
    </div>
  </div>

  <div class="d-flex justify-content-between align-items-center mt-4">
    <%= link_to "Cancelar", showrooms_path, class: "btn btn-outline-secondary" %>
    <%= f.submit(showroom.persisted? ? "Guardar cambios" : "Crear sala", class: "btn btn-primary px-4 fw-bold") %>
  </div>
<% end %>
```

- [ ] **Step 6: Write `new.html.erb` and `edit.html.erb`**

```erb
<%# app/views/showrooms/new.html.erb %>
<div class="container-fluid py-4">
  <nav aria-label="breadcrumb" class="mb-3">
    <ol class="breadcrumb">
      <li class="breadcrumb-item"><%= link_to "Salas", showrooms_path, class: "text-decoration-none" %></li>
      <li class="breadcrumb-item active fw-bold">Nueva sala</li>
    </ol>
  </nav>
  <h2 class="fw-bold mb-4">Nueva sala</h2>
  <%= render "form", showroom: @showroom %>
</div>
```

```erb
<%# app/views/showrooms/edit.html.erb %>
<div class="container-fluid py-4">
  <nav aria-label="breadcrumb" class="mb-3">
    <ol class="breadcrumb">
      <li class="breadcrumb-item"><%= link_to "Salas", showrooms_path, class: "text-decoration-none" %></li>
      <li class="breadcrumb-item active fw-bold">Editar <%= @showroom.name %></li>
    </ol>
  </nav>
  <h2 class="fw-bold mb-4">Editar sala: <%= @showroom.name %></h2>
  <%= render "form", showroom: @showroom %>
</div>
```

- [ ] **Step 7: Write `index.html.erb`**

```erb
<%# app/views/showrooms/index.html.erb %>
<div class="d-flex justify-content-between align-items-start mb-4">
  <div>
    <h1 class="fw-bold mb-1"><i class="bi bi-shop me-2 text-primary"></i>Salas de exhibición</h1>
    <p class="text-muted mb-0">Catálogo de showrooms y reglas de clasificación de inventario.</p>
  </div>
  <%= link_to new_showroom_path, class: "btn btn-primary" do %>
    <i class="bi bi-plus-circle me-1"></i>Nueva sala
  <% end %>
</div>

<div class="card border-0 shadow-sm">
  <div class="card-body p-0">
    <table class="table table-hover align-middle mb-0">
      <thead class="table-light">
        <tr>
          <th>Nombre</th>
          <th>Código</th>
          <th>Principal</th>
          <th>Estado</th>
          <th class="text-end">Acciones</th>
        </tr>
      </thead>
      <tbody>
        <% @showrooms.each do |showroom| %>
          <tr>
            <td class="fw-semibold"><%= showroom.name %></td>
            <td><code><%= showroom.code %></code></td>
            <td>
              <% if showroom.is_main? %>
                <span class="badge bg-primary">Principal</span>
              <% end %>
            </td>
            <td>
              <% if showroom.active? %>
                <span class="badge bg-success-subtle text-success-emphasis border border-success-subtle">Activa</span>
              <% else %>
                <span class="badge bg-secondary-subtle text-secondary-emphasis border">Inactiva</span>
              <% end %>
            </td>
            <td class="text-end">
              <%= link_to edit_showroom_path(showroom), class: "btn btn-sm btn-outline-secondary" do %>
                <i class="bi bi-pencil"></i>
              <% end %>
              <%= button_to showroom_path(showroom), method: :delete,
                    class: "btn btn-sm btn-outline-danger d-inline-block",
                    data: { turbo_confirm: "¿Eliminar la sala #{showroom.name}?" } do %>
                <i class="bi bi-trash"></i>
              <% end %>
            </td>
          </tr>
        <% end %>
      </tbody>
    </table>
  </div>
</div>
```

- [ ] **Step 8: Write the controller test**

```ruby
# test/controllers/showrooms_controller_test.rb
require "test_helper"

class ShowroomsControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    sign_in users(:admin)
    @showroom = showrooms(:palmares)
  end

  test "should get index" do
    get showrooms_url
    assert_response :success
  end

  test "should get new" do
    get new_showroom_url
    assert_response :success
  end

  test "should create showroom" do
    assert_difference("Showroom.count") do
      post showrooms_url, params: { showroom: { name: "Sala Nueva", code: "SN", order_number_prefixes: ["4"] } }
    end

    assert_redirected_to showrooms_url
    assert_equal ["4"], Showroom.last.order_number_prefixes_array
  end

  test "should get edit" do
    get edit_showroom_url(@showroom)
    assert_response :success
  end

  test "should update showroom" do
    patch showroom_url(@showroom),
      params: { showroom: { name: @showroom.name, code: @showroom.code, order_number_prefixes: ["2", "3", "5"] } }

    assert_redirected_to showrooms_url
    assert_equal ["2", "3", "5"], @showroom.reload.order_number_prefixes_array
  end

  test "activating is_main on another showroom demotes the previous main" do
    other = showrooms(:escazu)
    patch showroom_url(other), params: { showroom: { name: other.name, code: other.code, is_main: true } }

    assert other.reload.is_main?
    assert_not @showroom.reload.is_main?
  end

  test "should destroy showroom" do
    destroyable = Showroom.create!(name: "Sala Temporal", code: "ST")

    assert_difference("Showroom.count", -1) do
      delete showroom_url(destroyable)
    end

    assert_redirected_to showrooms_url
  end
end
```

- [ ] **Step 9: Run it to confirm it fails, then run again after the code above is in place**

```bash
bin/rails test test/controllers/showrooms_controller_test.rb
```

First run expected: routing errors (`undefined method 'showrooms_url'`). After Steps 2–7 are saved, re-run — expected: `7 runs, ... 0 failures, 0 errors`.

- [ ] **Step 10: Commit**

```bash
git add config/routes.rb app/controllers/showrooms_controller.rb app/javascript/controllers/tag_list_controller.js \
  app/views/showrooms test/fixtures/users.yml test/controllers/showrooms_controller_test.rb
git commit -m "Agregar CRUD de Showroom con catálogos JSON tipo tags y fixture admin"
```

---

## Task 4: `InventoryMovement` migration — rework `sala` into `showroom`/`source`/`flag`

**Files:**
- Create: `db/migrate/20260608130001_rework_inventory_movements_for_showrooms.rb`

The module is not in production and the spec explicitly says no data migration is needed, so this is a destructive-but-safe rework of an unused table.

- [ ] **Step 1: Write the migration**

```ruby
class ReworkInventoryMovementsForShowrooms < ActiveRecord::Migration[7.2]
  def change
    remove_index :inventory_movements, name: "index_inventory_movements_unique_item"
    remove_column :inventory_movements, :sala, :string

    add_column :inventory_movements, :showroom_id, :integer
    add_column :inventory_movements, :source, :string, default: "synced", null: false
    add_column :inventory_movements, :flag, :string

    add_index :inventory_movements, :showroom_id
    add_index :inventory_movements, :source
    add_index :inventory_movements, :flag
    add_index :inventory_movements, %i[delivery_item_id movement_type showroom_id],
      name: "index_inventory_movements_unique_item",
      unique: true,
      where: "delivery_item_id IS NOT NULL"

    add_foreign_key :inventory_movements, :showrooms
  end
end
```

- [ ] **Step 2: Run the migration**

```bash
bin/rails db:migrate
```

Expected: `== 20260608130001 ReworkInventoryMovementsForShowrooms: migrated`. `db/schema.rb` now shows `inventory_movements` without `sala`, with `showroom_id`/`source`/`flag` columns, the renamed unique index, and an FK to `showrooms`.

- [ ] **Step 3: Commit**

```bash
git add db/migrate/20260608130001_rework_inventory_movements_for_showrooms.rb db/schema.rb
git commit -m "Reemplazar columna sala por showroom_id/source/flag en inventory_movements"
```

---

## Task 5: `InventoryMovement` model rework + tests

**Files:**
- Modify: `app/models/inventory_movement.rb`
- Create: `test/models/inventory_movement_test.rb`

- [ ] **Step 1: Write the failing model test**

```ruby
# test/models/inventory_movement_test.rb
require "test_helper"

class InventoryMovementTest < ActiveSupport::TestCase
  setup do
    @showroom = showrooms(:palmares)
    @product  = products(:one)
  end

  def build_movement(attrs = {})
    InventoryMovement.new({
      movement_type: "entry", showroom: @showroom, product: @product,
      quantity: 1, status: "resolved", source: "synced", delivery_date: Date.current
    }.merge(attrs))
  end

  test "valid with default source synced and no flag" do
    movement = build_movement
    assert movement.valid?
    assert_equal "synced", movement.source
    assert_nil movement.flag
  end

  test "accepts manual source and stock_missing flag" do
    movement = build_movement(source: "manual", flag: "stock_missing")
    assert movement.valid?
  end

  test "rejects unknown source" do
    movement = build_movement(source: "imported")
    assert_not movement.valid?
    assert_includes movement.errors[:source], "is not included in the list"
  end

  test "rejects unknown flag but allows nil" do
    movement = build_movement(flag: "weird")
    assert_not movement.valid?
    assert_includes movement.errors[:flag], "is not included in the list"

    assert build_movement(flag: nil).valid?
  end

  test "type_label and source_label read naturally" do
    assert_equal "Entrada", build_movement(movement_type: "entry").type_label
    assert_equal "Salida", build_movement(movement_type: "exit").type_label
    assert_equal "Stock inicial", build_movement(movement_type: "initial").type_label
    assert_equal "Automático", build_movement(source: "synced").source_label
    assert_equal "Manual", build_movement(source: "manual").source_label
  end

  test "stock_by_product_and_showroom groups confirmed+resolved quantities by showroom" do
    other_showroom = showrooms(:escazu)

    InventoryMovement.create!(movement_type: "entry", showroom: @showroom, product: @product,
      quantity: 5, status: "resolved", source: "synced", delivery_date: Date.current)
    InventoryMovement.create!(movement_type: "exit", showroom: other_showroom, product: @product,
      quantity: 2, status: "resolved", source: "synced", delivery_date: Date.current)

    raw = InventoryMovement.stock_by_product_and_showroom

    assert_equal 5, raw[[@product.id, @showroom.id, "entry"]]
    assert_equal 2, raw[[@product.id, other_showroom.id, "exit"]]
  end
end
```

- [ ] **Step 2: Run it to confirm it fails**

```bash
bin/rails test test/models/inventory_movement_test.rb
```

Expected: failures referencing `SALAS`/`sala` validation errors, `NoMethodError: undefined method 'source'`, or `stock_by_product_and_showroom` not existing.

- [ ] **Step 3: Rewrite the model**

```ruby
# app/models/inventory_movement.rb
class InventoryMovement < ApplicationRecord
  belongs_to :inventory_sync, optional: true
  belongs_to :product, optional: true
  belongs_to :showroom, optional: true

  TYPES    = %w[entry exit initial].freeze
  STATUSES = %w[resolved unresolved ignored].freeze
  SOURCES  = %w[synced manual].freeze
  FLAGS    = %w[stock_missing].freeze

  validates :movement_type, inclusion: { in: TYPES }
  validates :status, inclusion: { in: STATUSES }
  validates :source, inclusion: { in: SOURCES }
  validates :flag, inclusion: { in: FLAGS }, allow_nil: true
  validates :quantity, numericality: { greater_than: 0 }

  scope :resolved,   -> { where(status: "resolved") }
  scope :unresolved, -> { where(status: "unresolved") }
  scope :ignored,    -> { where(status: "ignored") }
  scope :flagged,    -> { where.not(flag: nil) }

  scope :confirmed_only, -> {
    joins("LEFT OUTER JOIN inventory_syncs ON inventory_syncs.id = inventory_movements.inventory_sync_id")
      .where(
        "inventory_movements.inventory_sync_id IS NULL OR inventory_syncs.status = 'confirmed'"
      )
  }

  def self.stock_by_product_and_showroom
    confirmed_only
      .resolved
      .where.not(product_id: nil)
      .group(:product_id, :showroom_id, :movement_type)
      .sum(:quantity)
  end

  def self.current_stock_for(product_id:, showroom_id:)
    sums = confirmed_only
      .resolved
      .where(product_id: product_id, showroom_id: showroom_id)
      .group(:movement_type)
      .sum(:quantity)

    sums.fetch("entry", 0) + sums.fetch("initial", 0) - sums.fetch("exit", 0)
  end

  def type_label
    case movement_type
    when "entry"   then "Entrada"
    when "exit"    then "Salida"
    when "initial" then "Stock inicial"
    end
  end

  def source_label
    source == "manual" ? "Manual" : "Automático"
  end
end
```

- [ ] **Step 4: Run the test again to confirm it passes**

```bash
bin/rails test test/models/inventory_movement_test.rb
```

Expected: `6 runs, ... 0 failures, 0 errors`

- [ ] **Step 5: Commit**

```bash
git add app/models/inventory_movement.rb test/models/inventory_movement_test.rb
git commit -m "Reemplazar sala por showroom/source/flag en InventoryMovement"
```

---

## Task 6: Rewrite `InventoryClassifier` (two independent rules on structured data)

**Files:**
- Modify: `app/services/inventory_classifier.rb`
- Modify: `test/services/inventory_classifier_test.rb`

This removes ALL the regex machinery (`NALAKALU_RE`, `ESCAZU_RE`, `GUANACASTE_RE`, `CUSTOMER_ORDER_RE`, `MANDADO_RE`, `EXIT_SALA_RE`) per the spec's "Clasificación automática" section, and returns `Showroom` records (not string codes) in `Result#showroom`.

- [ ] **Step 1: Replace the test file with cases for the two independent rules**

```ruby
# test/services/inventory_classifier_test.rb
require "test_helper"

class InventoryClassifierTest < ActiveSupport::TestCase
  def item(name, qty = 1)
    { "id" => rand(100_000), "product_name" => name, "quantity_delivered" => qty }
  end

  def delivery(order_number:, items: [], source_showroom: nil, destination_showroom: nil)
    {
      "order_number" => order_number,
      "items" => items,
      "source_showroom" => source_showroom,
      "destination_showroom" => destination_showroom
    }
  end

  setup do
    @palmares   = showrooms(:palmares)
    @escazu     = showrooms(:escazu)
    @guanacaste = showrooms(:guanacaste)
  end

  test "genera entrada cuando la entrega trae destination_showroom estructurado y conocido" do
    d = delivery(
      order_number: "MOV-001",
      items: [item("Sofá 3 puestos")],
      destination_showroom: { "id" => 1, "name" => @escazu.name, "code" => @escazu.code }
    )

    entries = InventoryClassifier.classify(d).select { |r| r.type == "entry" }

    assert_equal 1, entries.size
    assert_equal @escazu, entries.first.showroom
  end

  test "genera salida cuando la entrega trae source_showroom estructurado y conocido" do
    d = delivery(
      order_number: "MOV-002",
      items: [item("Sofá 3 puestos")],
      source_showroom: { "id" => 2, "name" => @palmares.name, "code" => @palmares.code }
    )

    exits = InventoryClassifier.classify(d).select { |r| r.type == "exit" }

    assert_equal 1, exits.size
    assert_equal @palmares, exits.first.showroom
  end

  test "puede generar entrada y salida simultáneas cuando ambos showrooms vienen estructurados" do
    d = delivery(
      order_number: "MOV-003",
      items: [item("Sofá 3 puestos")],
      source_showroom: { "id" => 2, "name" => @palmares.name, "code" => @palmares.code },
      destination_showroom: { "id" => 1, "name" => @escazu.name, "code" => @escazu.code }
    )

    results = InventoryClassifier.classify(d)

    assert_equal 1, results.count { |r| r.type == "exit" && r.showroom == @palmares }
    assert_equal 1, results.count { |r| r.type == "entry" && r.showroom == @escazu }
  end

  test "ignora showrooms estructurados con código que no corresponde a ninguna sala activa" do
    d = delivery(
      order_number: "MOV-004",
      items: [item("Silla comedor")],
      source_showroom: { "id" => 9, "name" => "Bodega Central", "code" => "BOD" }
    )

    assert InventoryClassifier.classify(d).none? { |r| r.type == "exit" }
  end

  test "genera entrada a la sala principal cuando el order_number coincide con sus prefijos configurados" do
    d = delivery(
      order_number: "2-00045",
      items: [item("Sofá 3 puestos"), item("Mesa de centro")]
    )

    entries = InventoryClassifier.classify(d).select { |r| r.type == "entry" }

    assert_equal 2, entries.size
    assert entries.all? { |r| r.showroom == @palmares }
  end

  test "no genera entrada de reabastecimiento si el order_number no coincide con los prefijos de la sala principal" do
    @palmares.update!(order_number_prefixes: ["9"])

    d = delivery(order_number: "2-00045", items: [item("Sofá 3 puestos")])

    assert InventoryClassifier.classify(d).none? { |r| r.type == "entry" }
  end

  test "ambas reglas son independientes: pueden disparar movimientos distintos para la misma entrega" do
    d = delivery(
      order_number: "2-00099",
      items: [item("Sofá 3 puestos")],
      source_showroom: { "id" => 2, "name" => @escazu.name, "code" => @escazu.code }
    )

    results = InventoryClassifier.classify(d)

    assert_equal 1, results.count { |r| r.type == "exit"  && r.showroom == @escazu }
    assert_equal 1, results.count { |r| r.type == "entry" && r.showroom == @palmares }
  end

  test "ignora ítems con cantidad entregada cero o negativa" do
    d = delivery(
      order_number: "2-00100",
      items: [item("Sofá 3 puestos", 0), item("Mesa de centro", -1)],
      destination_showroom: { "id" => 1, "name" => @escazu.name, "code" => @escazu.code }
    )

    assert_empty InventoryClassifier.classify(d)
  end
end
```

- [ ] **Step 2: Run it to confirm it fails**

```bash
bin/rails test test/services/inventory_classifier_test.rb
```

Expected: failures like `NoMethodError: undefined method 'showroom' for #<struct InventoryClassifier::Result ...>` (the old `Result` struct has `:sala`, not `:showroom`) and assertion failures from the old regex-based classification.

- [ ] **Step 3: Rewrite the classifier**

```ruby
# app/services/inventory_classifier.rb
class InventoryClassifier
  Result = Struct.new(:type, :showroom, :item, keyword_init: true)

  def self.classify(delivery)
    new(delivery).classify
  end

  def initialize(delivery)
    @delivery     = delivery
    @order_number = delivery["order_number"].to_s
  end

  def classify
    items = Array(@delivery["items"]).select { |item| item["quantity_delivered"].to_f > 0 }
    return [] if items.empty?

    results = []
    add_inter_sala_results(items, results)
    add_main_restock_results(items, results)
    results
  end

  private

  # Regla 1: movimiento entre salas — basada en los datos estructurados
  # source_showroom/destination_showroom de la entrega. Ambos, uno solo,
  # o ninguno pueden estar presentes; cada uno genera sus propios movimientos.
  def add_inter_sala_results(items, results)
    source      = matching_showroom(@delivery["source_showroom"])
    destination = matching_showroom(@delivery["destination_showroom"])
    return unless source || destination

    items.each do |item|
      results << Result.new(type: "exit",  showroom: source,      item: item) if source
      results << Result.new(type: "entry", showroom: destination, item: item) if destination
    end
  end

  # Regla 2: reabastecimiento de la sala principal — independiente de la regla 1.
  # Si el order_number empieza con alguno de los order_number_prefixes
  # configurados en la sala marcada como is_main, genera una entrada hacia ella.
  def add_main_restock_results(items, results)
    main = main_showroom
    return unless main && restock_order?(main)

    items.each { |item| results << Result.new(type: "entry", showroom: main, item: item) }
  end

  def matching_showroom(showroom_data)
    return nil unless showroom_data.is_a?(Hash)

    showrooms_by_code[showroom_data["code"].to_s.upcase]
  end

  def main_showroom
    showrooms_by_code.values.find(&:is_main?)
  end

  def restock_order?(showroom)
    prefixes = showroom.order_number_prefixes_array
    prefixes.present? && prefixes.any? { |prefix| @order_number.start_with?(prefix) }
  end

  def showrooms_by_code
    @showrooms_by_code ||= Showroom.active.index_by(&:code)
  end
end
```

- [ ] **Step 4: Run the test again to confirm it passes**

```bash
bin/rails test test/services/inventory_classifier_test.rb
```

Expected: `8 runs, ... 0 failures, 0 errors`

- [ ] **Step 5: Commit**

```bash
git add app/services/inventory_classifier.rb test/services/inventory_classifier_test.rb
git commit -m "Reescribir InventoryClassifier con reglas basadas en datos estructurados de Showroom"
```

---

## Task 7: `InventoryResolver` memoization rework + `SyncInventoryJob` update + tests

**Files:**
- Modify: `app/services/inventory_resolver.rb`
- Modify: `app/jobs/sync_inventory_job.rb`
- Create: `test/services/inventory_resolver_test.rb`

The spec's memoization snippet (`decoded_by_name = Hash.new { |h, name| h[name] = ProductDecoder.decode(name) }`) only achieves "una sola vez por sync" if **one `InventoryResolver` instance processes every delivery in the run** — today `SyncInventoryJob` instantiates a fresh resolver per delivery via `InventoryResolver.resolve_delivery(delivery, sync)`, which would memoize per-delivery, not per-sync. So the entry point becomes `InventoryResolver.resolve_deliveries(deliveries, sync)`, which is only called from `SyncInventoryJob` (confirmed via grep — no other call sites or specs reference `resolve_delivery`).

- [ ] **Step 1: Write the failing resolver test (asserts `ProductDecoder.decode` is called once per unique name across the whole run)**

```ruby
# test/services/inventory_resolver_test.rb
require "test_helper"

class InventoryResolverTest < ActiveSupport::TestCase
  setup do
    @sync = InventorySync.create!(
      from_date: Date.current, to_date: Date.current,
      status: "pending_review", synced_at: Time.current
    )
  end

  def item(name, qty = 1)
    { "id" => rand(1_000_000), "product_name" => name, "quantity_delivered" => qty }
  end

  def delivery(order_number:, items:)
    {
      "id" => rand(100_000),
      "order_number" => order_number,
      "delivery_date" => Date.current.to_s,
      "client" => { "name" => "Cliente Genérico" },
      "items" => items,
      "source_showroom" => nil,
      "destination_showroom" => nil
    }
  end

  test "decodifica cada nombre de producto único una sola vez por corrida, sin importar cuántas entregas/ítems lo repitan" do
    deliveries = [
      delivery(order_number: "2-001", items: [item("Sofá 3 puestos"), item("Mesa de centro")]),
      delivery(order_number: "2-002", items: [item("Sofá 3 puestos"), item("Sofá 3 puestos")]),
      delivery(order_number: "3-003", items: [item("Mesa de centro")])
    ]

    decode_calls = []
    fake_decode = ->(name) {
      decode_calls << name
      ProductDecoder::Result.new(has_variants: false, base_product: nil, variants: [], unrecognized_codes: [])
    }

    ProductDecoder.stub :decode, fake_decode do
      InventoryResolver.resolve_deliveries(deliveries, @sync)
    end

    assert_equal ["Sofá 3 puestos", "Mesa de centro"], decode_calls.uniq.sort
    assert_equal 2, decode_calls.size,
      "ProductDecoder.decode debe invocarse una sola vez por nombre único en toda la corrida"
  end
end
```

- [ ] **Step 2: Run it to confirm it fails**

```bash
bin/rails test test/services/inventory_resolver_test.rb
```

Expected: `NoMethodError: undefined method 'resolve_deliveries' for InventoryResolver:Class`

- [ ] **Step 3: Rewrite the resolver**

```ruby
# app/services/inventory_resolver.rb
class InventoryResolver
  def self.resolve_deliveries(deliveries, sync)
    new(sync).resolve(deliveries)
  end

  def initialize(sync)
    @sync = sync
    # Memoización por corrida: cada product_name único se decodifica una sola
    # vez sin importar cuántas entregas/ítems lo repitan en este sync.
    @decoded_by_name = Hash.new { |h, name| h[name] = ProductDecoder.decode(name) }
  end

  def resolve(deliveries)
    deliveries.flat_map { |delivery| resolve_delivery(delivery) }
  end

  private

  def resolve_delivery(delivery)
    classified = InventoryClassifier.classify(delivery)
    return [] if classified.empty?

    results = []

    classified.each do |c|
      item     = c.item
      showroom = c.showroom

      next if confirmed_duplicate?(item["id"], c.type, showroom.id)

      decoding   = @decoded_by_name[item["product_name"].to_s]
      product_id = decoding.base_product&.id
      status     = product_id.present? ? "resolved" : "unresolved"

      movement = InventoryMovement.find_or_initialize_by(
        delivery_item_id: item["id"],
        movement_type:    c.type,
        showroom_id:      showroom.id
      )

      movement.assign_attributes(
        inventory_sync:   @sync,
        product_id:       product_id,
        delivery_id:      delivery["id"],
        delivery_date:    delivery["delivery_date"],
        order_number:     delivery["order_number"],
        client_name:      delivery.dig("client", "name"),
        product_name_raw: item["product_name"],
        quantity:         item["quantity_delivered"].to_f,
        source:           "synced",
        status:           movement.persisted? ? movement.status : status
      )

      if movement.save
        results << movement
      else
        Rails.logger.error "[InventoryResolver] #{movement.errors.full_messages.join(", ")} — #{item["product_name"]}"
      end
    end

    results
  end

  def confirmed_duplicate?(item_id, movement_type, showroom_id)
    return false if item_id.nil?

    InventoryMovement
      .confirmed_only
      .where(delivery_item_id: item_id, movement_type: movement_type, showroom_id: showroom_id)
      .exists?
  end
end
```

- [ ] **Step 4: Update the job to call the new entry point**

In `app/jobs/sync_inventory_job.rb`, replace:

```ruby
    movements = deliveries.flat_map do |delivery|
      InventoryResolver.resolve_delivery(delivery, sync)
    end
```

with:

```ruby
    movements = InventoryResolver.resolve_deliveries(deliveries, sync)
```

- [ ] **Step 5: Run the resolver test again to confirm it passes**

```bash
bin/rails test test/services/inventory_resolver_test.rb
```

Expected: `1 runs, ... 0 failures, 0 errors`

- [ ] **Step 6: Run the classifier + resolver + job-adjacent suites together as a regression check**

```bash
bin/rails test test/services/inventory_classifier_test.rb test/services/inventory_resolver_test.rb test/models/inventory_movement_test.rb test/models/logistics_sync_cursor_test.rb
```

Expected: all green, `0 failures, 0 errors`.

- [ ] **Step 7: Commit**

```bash
git add app/services/inventory_resolver.rb app/jobs/sync_inventory_job.rb test/services/inventory_resolver_test.rb
git commit -m "Memoizar ProductDecoder.decode por corrida en InventoryResolver para resolver el cuello de botella"
```

---

## Task 8: Update `inventories` controller + views to use `Showroom`

**Files:**
- Modify: `app/controllers/inventories_controller.rb`
- Modify: `app/views/inventories/index.html.erb`
- Modify: `app/views/inventories/new_initial_stock.html.erb`
- Modify: `app/views/inventories/_product_movements_modal.html.erb`

This task has no new automated tests of its own (no controller test exists for `InventoriesController` and the spec doesn't add one) — verify manually per Step 5.

- [ ] **Step 1: Update the controller**

In `app/controllers/inventories_controller.rb`:

Replace the `index` action body with:

```ruby
  def index
    @pending_syncs = InventorySync.pending.ordered
    @recent_syncs  = InventorySync.confirmed.ordered.limit(5)

    raw = InventoryMovement.stock_by_product_and_showroom
    @stock, @product_ids = build_stock_table(raw)
    @products  = Product.where(id: @product_ids).order(:name).index_by(&:id)
    @showrooms = Showroom.active.order(is_main: :desc, name: :asc)
    @flagged_count = InventoryMovement.flagged.count

    @from = params[:from] || Date.current.beginning_of_week.to_s
    @to   = params[:to]   || Date.current.end_of_week.to_s
  end
```

Replace `new_initial_stock`/`create_initial_stock`:

```ruby
  def new_initial_stock
    @movement  = InventoryMovement.new(movement_type: "initial", source: "manual", delivery_date: Date.current)
    @products  = Product.where(active: true).order(:name)
    @showrooms = Showroom.active.order(is_main: :desc, name: :asc)
  end

  def create_initial_stock
    @movement = InventoryMovement.new(
      initial_stock_params.merge(movement_type: "initial", source: "manual", status: "resolved")
    )
    if @movement.save
      redirect_to inventory_path, notice: "Stock inicial cargado correctamente."
    else
      @products  = Product.where(active: true).order(:name)
      @showrooms = Showroom.active.order(is_main: :desc, name: :asc)
      render :new_initial_stock, status: :unprocessable_entity
    end
  end
```

Replace `build_stock_table` and `initial_stock_params` in the `private` section:

```ruby
  # raw = { [product_id, showroom_id, movement_type] => qty }
  # Returns [stock_hash, product_ids]
  # stock_hash = { [product_id, showroom_id] => net_quantity }
  def build_stock_table(raw)
    stock = Hash.new(0)
    raw.each do |(product_id, showroom_id, movement_type), qty|
      factor = movement_type.in?(%w[entry initial]) ? 1 : -1
      stock[[product_id, showroom_id]] += factor * qty
    end
    product_ids = stock.keys.map(&:first).uniq
    [stock, product_ids]
  end

  def initial_stock_params
    params.require(:inventory_movement).permit(:product_id, :showroom_id, :quantity, :delivery_date, :notes)
  end
```

- [ ] **Step 2: Update `inventories/index.html.erb`**

Replace the header `<div class="d-flex gap-2 flex-wrap">` block (lines 7–14) with one that adds the manual-exit and alerts shortcuts (with a discrepancy badge):

```erb
  <div class="d-flex gap-2 flex-wrap">
    <%= link_to new_inventory_initial_stock_path, class: "btn btn-outline-secondary" do %>
      <i class="bi bi-plus-circle me-1"></i>Stock Inicial
    <% end %>
    <%= link_to new_inventory_exit_path, class: "btn btn-outline-danger" do %>
      <i class="bi bi-box-arrow-up me-1"></i>Registrar salida
    <% end %>
    <%= link_to inventory_alerts_path, class: "btn btn-outline-warning" do %>
      <i class="bi bi-exclamation-triangle me-1"></i>Alertas de inventario
      <% if @flagged_count > 0 %>
        <span class="badge rounded-pill bg-danger ms-1"><%= @flagged_count %></span>
      <% end %>
    <% end %>
    <button class="btn btn-primary" data-bs-toggle="collapse" data-bs-target="#syncForm">
      <i class="bi bi-arrow-repeat me-1"></i>Sincronizar
    </button>
  </div>
```

Then replace every `@salas`/`SALA_LABELS` reference in the stock table (around lines 81–113) — the `<thead>` row:

```erb
            <tr>
              <th>Producto</th>
              <% @showrooms.each do |showroom| %>
                <th class="text-center"><%= showroom.name %></th>
              <% end %>
              <th class="text-center fw-bold">Total</th>
            </tr>
```

— and the `<tbody>` row body:

```erb
                <% total = 0 %>
                <% @showrooms.each do |showroom| %>
                  <% qty = @stock[[ product.id, showroom.id ]] || 0 %>
                  <% total += qty %>
                  <td class="text-center">
                    <% if qty > 0 %>
                      <span class="badge bg-success-subtle text-success-emphasis border border-success-subtle px-2"><%= qty %></span>
                    <% elsif qty < 0 %>
                      <span class="badge bg-danger-subtle text-danger-emphasis border border-danger-subtle px-2"><%= qty %></span>
                    <% else %>
                      <span class="text-muted small">—</span>
                    <% end %>
                  </td>
                <% end %>
```

(The `<td class="text-center fw-bold">` total cell that follows is unchanged.)

- [ ] **Step 3: Update `inventories/new_initial_stock.html.erb`**

Replace the "Sala" `<div class="mb-4">` block (lines 38–44):

```erb
          <div class="mb-4">
            <label class="form-label fw-semibold">Sala <span class="text-danger">*</span></label>
            <%= f.select :showroom_id,
                  @showrooms.map { |s| [s.name, s.id] },
                  { include_blank: "— Selecciona una sala —" },
                  class: "form-select shadow-sm" %>
          </div>
```

- [ ] **Step 4: Update `inventories/_product_movements_modal.html.erb`**

Replace the `<th>Sala</th>` header with a "Sala" + "Origen" pair, and the row cells accordingly — replace the `<thead>`:

```erb
        <thead class="table-light">
          <tr>
            <th>Fecha</th>
            <th>Tipo</th>
            <th>Sala</th>
            <th>Origen</th>
            <th class="text-center">Cant.</th>
            <th>Pedido</th>
          </tr>
        </thead>
```

and the row body (replace `<td><span class="badge bg-secondary"><%= m.sala_label %></span></td>` and add the source cell right after it):

```erb
              <td><span class="badge bg-secondary"><%= m.showroom&.name || "—" %></span></td>
              <td>
                <span class="badge <%= m.source == 'manual' ? 'bg-info-subtle text-info-emphasis border border-info-subtle' : 'bg-light text-muted border' %>">
                  <%= m.source_label %>
                </span>
              </td>
```

- [ ] **Step 5: Manually verify in the browser**

```bash
bin/rails server
```

Visit `/inventory` as an admin user — the stock table header should show real showroom names (Sala Palmares / Sala Escazú / Sala Guanacaste, assuming you've created them via `/showrooms/new`), the "Registrar salida" and "Alertas de inventario" buttons should be visible, and `/inventory/initial_stock/new` should show a "Sala" select populated from active showrooms. Stop the server with Ctrl+C when done.

- [ ] **Step 6: Commit**

```bash
git add app/controllers/inventories_controller.rb app/views/inventories/index.html.erb \
  app/views/inventories/new_initial_stock.html.erb app/views/inventories/_product_movements_modal.html.erb
git commit -m "Migrar inventories#index y formularios de stock inicial a Showroom"
```

---

## Task 9: Update `inventory_syncs#show` to display `Showroom` names

**Files:**
- Modify: `app/views/inventory_syncs/show.html.erb`

- [ ] **Step 1: Replace the two `m.sala_label` references**

Line 86 (inside the "Ítems sin resolver" table, "Tipo / Sala" column):

```erb
                  <span class="badge bg-secondary"><%= m.showroom&.name || "—" %></span>
```

Line 161 (inside the "Movimientos resueltos / ignorados" table, "Sala" column):

```erb
                <td><span class="badge bg-secondary"><%= m.showroom&.name || "—" %></span></td>
```

- [ ] **Step 2: Manually verify**

Trigger a sync from `/inventory` (button "Sincronizar") and open the resulting `InventorySync#show` page — the "Sala" badges should show real showroom names instead of `SP`/`SE`/`SG` codes. (If no deliveries are returned in the sync window, you can still confirm the page renders without `NoMethodError: undefined method 'sala_label'`.)

- [ ] **Step 3: Commit**

```bash
git add app/views/inventory_syncs/show.html.erb
git commit -m "Mostrar nombre real de Showroom en la revisión de sincronización"
```

---

## Task 10: Manual exits — "Registrar salida" flow

**Files:**
- Modify: `config/routes.rb`
- Create: `app/controllers/inventory_exits_controller.rb`
- Create: `app/views/inventory_exits/new.html.erb`
- Create: `test/controllers/inventory_exits_controller_test.rb`

There's no existing precedent in this codebase for stubbing `LogisticsApiClient` at the controller level (no `logistics_queries_controller_test.rb` exists and `LogisticsApiClient` has no test seams beyond its own Faraday-backed spec). We stub `LogisticsApiClient.new` with `Minitest::Object#stub` to return a small fake object — this is the standard Minitest technique for swapping out a collaborator without adding a mocking gem (the project only has `minitest`, confirmed via `grep -in mocha\|webmock\|vcr Gemfile` returning nothing).

- [ ] **Step 1: Add routes**

In `config/routes.rb`, right after the `get "inventory/product/:product_id/movements" ...` line (around line 169), add:

```ruby

  get  "inventory/exits/new", to: "inventory_exits#new",    as: :new_inventory_exit
  post "inventory/exits",     to: "inventory_exits#create", as: :inventory_exits
```

- [ ] **Step 2: Write the failing controller test**

```ruby
# test/controllers/inventory_exits_controller_test.rb
require "test_helper"

class InventoryExitsControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  class FakeLogisticsClient
    def initialize(deliveries = [])
      @deliveries = deliveries
    end

    def fetch_deliveries(*)
      @deliveries
    end
  end

  setup do
    sign_in users(:admin)
    @showroom = showrooms(:palmares)
    @product  = products(:one)
  end

  test "should get new" do
    get new_inventory_exit_url
    assert_response :success
  end

  test "consultar pedido muestra los datos de la entrega encontrada" do
    delivery = {
      "order_number" => "2-00123",
      "client" => { "name" => "Cliente de Prueba" },
      "delivery_date" => "2026-06-01",
      "items" => [{ "product_name" => "Sofá 3 puestos", "quantity_delivered" => 2 }]
    }

    LogisticsApiClient.stub :new, FakeLogisticsClient.new([delivery]) do
      get new_inventory_exit_url, params: { inventory_movement: { order_number: "2-00123" } }
    end

    assert_response :success
    assert_match "Cliente de Prueba", @response.body
  end

  test "consultar pedido muestra aviso cuando no se encuentra ninguna entrega" do
    LogisticsApiClient.stub :new, FakeLogisticsClient.new([]) do
      get new_inventory_exit_url, params: { inventory_movement: { order_number: "9-99999" } }
    end

    assert_response :success
    assert_match "No se encontró ningún pedido", @response.body
  end

  test "registra una salida con stock suficiente sin generar alerta" do
    InventoryMovement.create!(movement_type: "initial", source: "manual", status: "resolved",
      product: @product, showroom: @showroom, quantity: 5, delivery_date: Date.current)

    assert_difference("InventoryMovement.count") do
      post inventory_exits_url, params: {
        inventory_movement: { showroom_id: @showroom.id, product_id: @product.id, quantity: 2, notes: "Venta a cliente" }
      }
    end

    movement = InventoryMovement.order(:created_at).last
    assert_equal "exit", movement.movement_type
    assert_equal "manual", movement.source
    assert_equal "resolved", movement.status
    assert_nil movement.flag
    assert_redirected_to inventory_path
  end

  test "registra una salida con stock insuficiente y la marca con flag stock_missing" do
    assert_difference("InventoryMovement.count") do
      post inventory_exits_url, params: {
        inventory_movement: { showroom_id: @showroom.id, product_id: @product.id, quantity: 3, notes: "Venta a cliente" }
      }
    end

    movement = InventoryMovement.order(:created_at).last
    assert_equal "stock_missing", movement.flag
    assert_match "Alerta automática", movement.notes
  end
end
```

- [ ] **Step 3: Run it to confirm it fails**

```bash
bin/rails test test/controllers/inventory_exits_controller_test.rb
```

Expected: routing errors (`undefined method 'new_inventory_exit_url'` / `uninitialized constant InventoryExitsController`).

- [ ] **Step 4: Write the controller**

```ruby
# app/controllers/inventory_exits_controller.rb
class InventoryExitsController < ApplicationController
  before_action :authenticate_user!
  before_action :authorize_admin!

  def new
    @movement = InventoryMovement.new(movement_type: "exit", source: "manual", delivery_date: Date.current)
    @movement.assign_attributes(movement_params) if params[:inventory_movement].present?

    load_form_collections
    load_delivery_preview
    load_current_stock
  end

  def create
    @movement = InventoryMovement.new(
      movement_params.merge(movement_type: "exit", source: "manual", status: "resolved")
    )
    apply_stock_flag!
    load_form_collections

    if @movement.save
      notice = @movement.flag == "stock_missing" ? "Salida registrada con alerta de stock faltante." : "Salida registrada correctamente."
      redirect_to inventory_path, notice: notice
    else
      load_delivery_preview
      load_current_stock
      render :new, status: :unprocessable_entity
    end
  end

  private

  def movement_params
    params.fetch(:inventory_movement, {})
      .permit(:showroom_id, :product_id, :quantity, :order_number, :notes, :delivery_date)
  end

  def load_form_collections
    @showrooms = Showroom.active.order(is_main: :desc, name: :asc)
    @products  = Product.where(active: true).order(:name)
  end

  # El usuario puede ingresar un número de pedido para corroborar contra la API
  # de Rutas — esto solo informa, no crea ni modifica nada automáticamente.
  def load_delivery_preview
    return if @movement.order_number.blank?

    deliveries = LogisticsApiClient.new.fetch_deliveries(order_number: @movement.order_number)
    @delivery_preview = Array(deliveries).first
    @delivery_preview_error = "No se encontró ningún pedido con ese número." unless @delivery_preview
  rescue => e
    @delivery_preview_error = "No se pudo consultar el pedido: #{e.message}"
  end

  def load_current_stock
    return unless @movement.product_id.present? && @movement.showroom_id.present?

    @current_stock = InventoryMovement.current_stock_for(
      product_id: @movement.product_id, showroom_id: @movement.showroom_id
    )
  end

  # Si la cantidad solicitada excede el stock calculado (incluyendo stock = 0 /
  # inexistente), se guarda igual pero con flag: "stock_missing" y una nota automática.
  def apply_stock_flag!
    return unless @movement.product_id.present? && @movement.showroom_id.present?

    available = InventoryMovement.current_stock_for(
      product_id: @movement.product_id, showroom_id: @movement.showroom_id
    )
    return if @movement.quantity.to_f <= available

    @movement.flag = "stock_missing"
    @movement.notes = [
      @movement.notes.presence,
      "Alerta automática: se registró una salida de #{@movement.quantity} pero el stock calculado era #{available}."
    ].compact.join("\n\n")
  end
end
```

- [ ] **Step 5: Write the view**

```erb
<%# app/views/inventory_exits/new.html.erb %>
<div class="row justify-content-center">
  <div class="col-md-8 col-lg-6">
    <div class="card border-0 shadow-sm rounded-4 overflow-hidden">
      <div class="p-4 text-white" style="background: linear-gradient(145deg, #dc3545, #a02530);">
        <div class="d-flex align-items-center gap-3">
          <div class="bg-white text-danger rounded-3 shadow-sm d-flex justify-content-center align-items-center" style="width:50px;height:50px;">
            <i class="bi bi-box-arrow-up fs-3"></i>
          </div>
          <div>
            <h2 class="fw-bold mb-1">Registrar salida de inventario</h2>
            <p class="mb-0 small opacity-75">Verifica el pedido y el stock antes de confirmar.</p>
          </div>
        </div>
      </div>

      <div class="card-body p-4">
        <%= form_with model: @movement, url: inventory_exits_path do |f| %>

          <% if @movement.errors.any? %>
            <div class="alert alert-danger mb-4">
              <ul class="mb-0 ps-3">
                <% @movement.errors.full_messages.each do |msg| %>
                  <li><%= msg %></li>
                <% end %>
              </ul>
            </div>
          <% end %>

          <div class="mb-4">
            <label class="form-label fw-semibold">Sala de origen <span class="text-danger">*</span></label>
            <%= f.select :showroom_id, @showrooms.map { |s| [s.name, s.id] },
                  { include_blank: "— Selecciona una sala —" }, class: "form-select shadow-sm" %>
          </div>

          <div class="mb-4">
            <label class="form-label fw-semibold">
              Número de pedido <span class="text-muted fw-normal">(opcional, para corroborar)</span>
            </label>
            <div class="input-group">
              <%= f.text_field :order_number, class: "form-control shadow-sm", placeholder: "Ej: 2-00123" %>
              <button type="submit" class="btn btn-outline-primary"
                      formmethod="get" formaction="<%= new_inventory_exit_path %>">
                <i class="bi bi-search me-1"></i>Consultar
              </button>
            </div>
            <% if @movement.order_number.present? && (@delivery_preview || @delivery_preview_error) %>
              <% if @delivery_preview %>
                <div class="alert alert-info mt-2 mb-0 small">
                  <strong>Pedido encontrado</strong> —
                  Cliente: <%= @delivery_preview.dig("client", "name") || "—" %>
                  · Fecha: <%= @delivery_preview["delivery_date"] %>
                  <ul class="mb-0 mt-2">
                    <% Array(@delivery_preview["items"]).each do |item| %>
                      <li><%= item["product_name"] %> — cantidad entregada: <%= item["quantity_delivered"] %></li>
                    <% end %>
                  </ul>
                </div>
              <% else %>
                <div class="alert alert-warning mt-2 mb-0 small"><%= @delivery_preview_error %></div>
              <% end %>
            <% end %>
          </div>

          <div class="mb-4">
            <label class="form-label fw-semibold">Producto <span class="text-danger">*</span></label>
            <%= f.select :product_id, @products.map { |p| [p.name, p.id] },
                  { include_blank: "— Selecciona un producto —" }, class: "form-select shadow-sm" %>
            <button type="submit" class="btn btn-outline-secondary btn-sm mt-2"
                    formmethod="get" formaction="<%= new_inventory_exit_path %>">
              <i class="bi bi-eye me-1"></i>Ver stock actual en la sala seleccionada
            </button>
            <% if @current_stock %>
              <div class="alert <%= @current_stock.to_f <= 0 ? "alert-danger" : "alert-secondary" %> mt-2 mb-0 small">
                Stock actual calculado en esta sala: <strong><%= @current_stock %></strong>
                <% if @current_stock.to_f <= 0 %>
                  — si registras esta salida, quedará marcada con una alerta de stock faltante.
                <% end %>
              </div>
            <% end %>
          </div>

          <div class="mb-4">
            <label class="form-label fw-semibold">Cantidad que sale <span class="text-danger">*</span></label>
            <%= f.number_field :quantity, min: 0.01, step: 0.01, class: "form-control shadow-sm", placeholder: "Ej: 1" %>
          </div>

          <div class="mb-4">
            <label class="form-label fw-semibold">Notas <span class="text-muted fw-normal">(opcional)</span></label>
            <%= f.text_area :notes, rows: 2, class: "form-control shadow-sm",
                  placeholder: "Contexto adicional sobre esta salida" %>
          </div>

          <%= f.hidden_field :delivery_date, value: Date.current %>

          <div class="d-flex gap-2 justify-content-end">
            <%= link_to "Cancelar", inventory_path, class: "btn btn-outline-secondary" %>
            <%= f.submit "Registrar salida", class: "btn btn-danger px-4 fw-bold" %>
          </div>

        <% end %>
      </div>
    </div>
  </div>
</div>
```

- [ ] **Step 6: Run the test again to confirm it passes**

```bash
bin/rails test test/controllers/inventory_exits_controller_test.rb
```

Expected: `5 runs, ... 0 failures, 0 errors`

- [ ] **Step 7: Commit**

```bash
git add config/routes.rb app/controllers/inventory_exits_controller.rb app/views/inventory_exits \
  test/controllers/inventory_exits_controller_test.rb
git commit -m "Agregar flujo de registro manual de salidas con verificación de pedido y stock"
```

---

## Task 11: Inventory alerts — "Alertas de inventario" (discrepancy resolution)

**Files:**
- Modify: `config/routes.rb`
- Create: `app/controllers/inventory_alerts_controller.rb`
- Create: `app/views/inventory_alerts/index.html.erb`
- Create: `test/controllers/inventory_alerts_controller_test.rb`

Per the spec, resolving an alert should leave a trace of **how** it was fixed (e.g. by registering a corrective `initial` adjustment movement), not just clear the flag silently.

- [ ] **Step 1: Add routes**

In `config/routes.rb`, right after the two `inventory_exits` lines added in Task 10, add:

```ruby

  resources :inventory_alerts, only: [:index] do
    member { patch :resolve }
  end
```

- [ ] **Step 2: Write the failing controller test**

```ruby
# test/controllers/inventory_alerts_controller_test.rb
require "test_helper"

class InventoryAlertsControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    sign_in users(:admin)
    @showroom = showrooms(:palmares)
    @product  = products(:one)
    @alert = InventoryMovement.create!(
      movement_type: "exit", source: "manual", status: "resolved",
      product: @product, showroom: @showroom, quantity: 3, delivery_date: Date.current,
      flag: "stock_missing",
      notes: "Alerta automática: se registró una salida de 3 pero el stock calculado era 0."
    )
  end

  test "should get index and list flagged movements" do
    get inventory_alerts_url
    assert_response :success
    assert_match @product.name, @response.body
  end

  test "resuelve una alerta registrando un ajuste de stock initial y limpia el flag dejando trazabilidad" do
    assert_difference("InventoryMovement.count") do
      patch resolve_inventory_alert_url(@alert),
        params: { create_adjustment: "1", adjustment_quantity: "3", note: "Se confirmó conteo físico." }
    end

    @alert.reload
    assert_nil @alert.flag
    assert_match "Resolución", @alert.notes
    assert_match "Se confirmó conteo físico.", @alert.notes

    adjustment = InventoryMovement.order(:created_at).last
    assert_equal "initial", adjustment.movement_type
    assert_equal @product, adjustment.product
    assert_equal @showroom, adjustment.showroom
  end

  test "resuelve una alerta sin crear ajuste cuando no se solicita uno" do
    assert_no_difference("InventoryMovement.count") do
      patch resolve_inventory_alert_url(@alert), params: { note: "Era un error de digitación." }
    end

    @alert.reload
    assert_nil @alert.flag
    assert_match "Era un error de digitación.", @alert.notes
  end
end
```

- [ ] **Step 3: Run it to confirm it fails**

```bash
bin/rails test test/controllers/inventory_alerts_controller_test.rb
```

Expected: routing errors (`undefined method 'inventory_alerts_url'` / `uninitialized constant InventoryAlertsController`).

- [ ] **Step 4: Write the controller**

```ruby
# app/controllers/inventory_alerts_controller.rb
class InventoryAlertsController < ApplicationController
  before_action :authenticate_user!
  before_action :authorize_admin!
  before_action :set_alert, only: [:resolve]

  def index
    @alerts = InventoryMovement.flagged
      .includes(:product, :showroom)
      .order(created_at: :desc)
  end

  def resolve
    note = build_resolution_note
    adjustment = create_adjustment! if create_adjustment?

    note = "Resuelta registrando ajuste de stock ##{adjustment.id} por #{adjustment.quantity} unidad(es). #{note}".strip if adjustment

    @alert.update!(
      flag: nil,
      notes: [@alert.notes.presence, "[Resolución] #{note}".strip].compact.join("\n\n")
    )

    redirect_to inventory_alerts_path, notice: "Alerta resuelta y trazabilidad registrada."
  end

  private

  def set_alert
    @alert = InventoryMovement.find(params[:id])
  end

  def resolution_params
    params.permit(:create_adjustment, :adjustment_quantity, :note)
  end

  def create_adjustment?
    resolution_params[:create_adjustment] == "1" && resolution_params[:adjustment_quantity].present?
  end

  def create_adjustment!
    InventoryMovement.create!(
      movement_type: "initial", source: "manual", status: "resolved",
      product_id: @alert.product_id, showroom_id: @alert.showroom_id,
      quantity: resolution_params[:adjustment_quantity], delivery_date: Date.current,
      notes: "Ajuste de corrección para la alerta ##{@alert.id} (#{@alert.product&.name} · #{@alert.showroom&.name})."
    )
  end

  def build_resolution_note
    resolution_params[:note].presence || "Resuelta manualmente sin ajuste de stock."
  end
end
```

- [ ] **Step 5: Write the view**

```erb
<%# app/views/inventory_alerts/index.html.erb %>
<div class="d-flex justify-content-between align-items-start mb-4">
  <div>
    <h1 class="fw-bold mb-1"><i class="bi bi-exclamation-triangle me-2 text-warning"></i>Alertas de inventario</h1>
    <p class="text-muted mb-0">Discrepancias de stock detectadas al registrar salidas manuales.</p>
  </div>
  <%= link_to inventory_path, class: "btn btn-outline-secondary btn-sm" do %>
    <i class="bi bi-arrow-left me-1"></i>Volver al inventario
  <% end %>
</div>

<% if @alerts.empty? %>
  <div class="alert alert-success">
    <i class="bi bi-check-circle me-2"></i>No hay alertas de inventario pendientes.
  </div>
<% else %>
  <div class="card border-0 shadow-sm">
    <div class="card-body p-0">
      <table class="table align-middle mb-0">
        <thead class="table-light">
          <tr>
            <th>Producto</th>
            <th>Sala</th>
            <th class="text-center">Cant.</th>
            <th>Pedido</th>
            <th>Fecha</th>
            <th>Nota</th>
            <th class="text-end">Acciones</th>
          </tr>
        </thead>
        <tbody>
          <% @alerts.each do |alert| %>
            <tr>
              <td class="fw-semibold"><%= alert.product&.name || alert.product_name_raw %></td>
              <td><span class="badge bg-secondary"><%= alert.showroom&.name || "—" %></span></td>
              <td class="text-center"><%= alert.quantity %></td>
              <td class="text-muted small"><%= alert.order_number %></td>
              <td class="text-muted small"><%= alert.delivery_date&.strftime("%d/%m/%Y") %></td>
              <td class="text-muted small"><%= simple_format(alert.notes) %></td>
              <td class="text-end">
                <button class="btn btn-sm btn-outline-success" type="button"
                        data-bs-toggle="collapse" data-bs-target="#resolve-<%= alert.id %>">
                  <i class="bi bi-check-circle me-1"></i>Resolver
                </button>
              </td>
            </tr>
            <tr class="collapse" id="resolve-<%= alert.id %>">
              <td colspan="7" class="bg-light">
                <%= form_with url: resolve_inventory_alert_path(alert), method: :patch, class: "row g-2 align-items-end py-2" do |f| %>
                  <div class="col-md-3">
                    <div class="form-check">
                      <%= check_box_tag :create_adjustment, "1", false, class: "form-check-input", id: "adjust-#{alert.id}" %>
                      <%= label_tag "adjust-#{alert.id}", "Registrar ajuste de stock (initial)", class: "form-check-label small" %>
                    </div>
                    <%= number_field_tag :adjustment_quantity, nil, step: 0.01, min: 0.01,
                          class: "form-control form-control-sm mt-1", placeholder: "Cantidad a ajustar" %>
                  </div>
                  <div class="col-md-6">
                    <%= text_area_tag :note, nil, rows: 1, class: "form-control form-control-sm",
                          placeholder: "Nota de resolución (qué pasó / cómo se corrigió)" %>
                  </div>
                  <div class="col-md-3 text-end">
                    <%= submit_tag "Confirmar resolución", class: "btn btn-sm btn-success",
                          data: { turbo_confirm: "¿Marcar esta alerta como resuelta?" } %>
                  </div>
                <% end %>
              </td>
            </tr>
          <% end %>
        </tbody>
      </table>
    </div>
  </div>
<% end %>
```

- [ ] **Step 6: Run the test again to confirm it passes**

```bash
bin/rails test test/controllers/inventory_alerts_controller_test.rb
```

Expected: `3 runs, ... 0 failures, 0 errors`

- [ ] **Step 7: Commit**

```bash
git add config/routes.rb app/controllers/inventory_alerts_controller.rb app/views/inventory_alerts \
  test/controllers/inventory_alerts_controller_test.rb
git commit -m "Agregar vista de alertas de inventario con resolución trazable vía ajuste de stock"
```

---

## Task 12: Full regression run + `graphify update`

**Files:** none (verification only)

- [ ] **Step 1: Run the entire inventory-related test surface**

```bash
bin/rails test test/models/showroom_test.rb test/models/inventory_movement_test.rb \
  test/services/inventory_classifier_test.rb test/services/inventory_resolver_test.rb \
  test/controllers/showrooms_controller_test.rb test/controllers/inventory_exits_controller_test.rb \
  test/controllers/inventory_alerts_controller_test.rb test/models/logistics_sync_cursor_test.rb
```

Expected: all green, `0 failures, 0 errors`.

- [ ] **Step 2: Run the full suite to confirm no unrelated regressions**

```bash
bin/rails test
```

Expected: the same pre-existing failures noted in "Before you start" (`families_controller_test.rb`, `variant_types_controller_test.rb` — unrelated, no-admin-fixture issue) and nothing new failing. If anything in `procurement_resolver`/`product_decoder`/`logistics_api_client` specs newly fails, stop and investigate — those are shared services this rework must not regress.

- [ ] **Step 3: Update the knowledge graph**

```bash
graphify update .
```

- [ ] **Step 4: Final commit (only if `graphify update` produced changes worth tracking)**

```bash
git status
```

If `graphify-out/` changed, commit it separately:

```bash
git add graphify-out/
git commit -m "Actualizar grafo de conocimiento tras el rework de inventario de salas"
```
