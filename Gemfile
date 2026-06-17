source "https://rubygems.org"

# ── Core Rails ────────────────────────────────────────────────────────────────
gem "rails", "~> 7.2.3"
gem "sprockets-rails"
gem "puma", ">= 5.0"
gem "bootsnap", require: false

# ── Frontend / Hotwire ────────────────────────────────────────────────────────
gem "importmap-rails"
gem "turbo-rails"
gem "stimulus-rails"
gem "cssbundling-rails"
gem "jbuilder"

# ── Autenticación / Autorización ─────────────────────────────────────────────
gem "devise"
gem "omniauth-microsoft_graph"
gem "omniauth-rails_csrf_protection"

# ── HTTP / Integraciones externas ────────────────────────────────────────────
gem "faraday"
gem "faraday-retry"

# ── Background Jobs ───────────────────────────────────────────────────────────
gem "sidekiq"
gem "redis", "~> 5.0"
# connection_pool 3.x quitó la firma ConnectionPool.new(hash_posicional) que
# usa ActiveSupport::Cache::RedisCacheStore en Rails 7.2.3 (rompe el boot con
# "wrong number of arguments"). Fijado a 2.x hasta actualizar Rails.
gem "connection_pool", "~> 2.4"

# ── Procurement / Lógica de negocio ──────────────────────────────────────────
gem "fuzzy_match"
gem "fuzzy-string-match"
gem "with_advisory_lock", platforms: :ruby

# ── PDF ───────────────────────────────────────────────────────────────────────
gem "prawn"
gem "prawn-table"
gem "matrix"

# ── Paginación ────────────────────────────────────────────────────────────────
gem "pagy"

# ── Utilidades ────────────────────────────────────────────────────────────────
gem "csv"
gem "roo"
gem "caxlsx"
gem "tzinfo-data", platforms: %i[windows jruby]

group :development, :test do
  gem "dotenv-rails"
  gem "debug", platforms: %i[mri windows], require: "debug/prelude"
  gem "brakeman", require: false
  gem "sqlite3"
  gem "standard", ">= 1.35.1"
  gem "letter_opener"
  gem "derailed_benchmarks"
end

group :development do
  gem "web-console"
end

group :test do
  gem "capybara"
  gem "selenium-webdriver"
  gem "minitest", "~> 5.25"
end

group :production do
  gem "pg"
end

gem "sidekiq-cron", "~> 2.4"
