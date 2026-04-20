source "https://rubygems.org"

# ── Core Rails ────────────────────────────────────────────────────────────────
gem "rails", "~> 7.2.3"
gem "sprockets-rails"          # asset pipeline clásico
gem "puma", ">= 5.0"           # servidor web
gem "bootsnap", require: false # acelera boot cacheando bytecode

# ── Frontend / Hotwire ────────────────────────────────────────────────────────
gem "importmap-rails"          # ES modules sin bundler
gem "turbo-rails"              # Turbo Drive + Frames + Streams
gem "stimulus-rails"           # Stimulus JS controllers
gem "cssbundling-rails"        # CSS bundling (Bootstrap, etc.)
gem "jbuilder"                 # JSON views para APIs

# ── Autenticación / Autorización ─────────────────────────────────────────────
gem "devise"                              # autenticación de usuarios
gem "omniauth-microsoft_graph"            # OAuth con Microsoft 365
gem "omniauth-rails_csrf_protection"      # protección CSRF para OmniAuth

# ── Microsoft Graph (correo, calendario, etc.) ───────────────────────────────
gem "microsoft_graph"          # cliente REST para Microsoft Graph API

# ── HTTP / Integraciones externas ────────────────────────────────────────────
gem "faraday"                  # cliente HTTP flexible
gem "faraday-retry"            # middleware de reintentos para Faraday

# ── Background Jobs ───────────────────────────────────────────────────────────
gem "sidekiq"                  # procesamiento de jobs en background
gem "redis", "~> 5.0"          # backend de Sidekiq y caché

# ── Procurement / Lógica de negocio ──────────────────────────────────────────
gem "fuzzy_match"              # matching difuso de strings (ProductDecoder)
gem "fuzzy-string-match"       # distancia Jaro-Winkler para variantes
gem "with_advisory_lock", platforms: :ruby  # locks a nivel DB (solo PostgreSQL/MySQL)

# ── PDF ───────────────────────────────────────────────────────────────────────
gem "prawn"                    # generación de PDFs
gem "prawn-table"              # tablas para Prawn
gem "matrix"                   # dependencia de Prawn en Ruby 3.x+

# ── Paginación ────────────────────────────────────────────────────────────────
gem "pagy"
# ── Utilidades ────────────────────────────────────────────────────────────────
gem "csv"                      # parsing/generación de CSV (stdlib explícita en Ruby 3.x)
gem "tzinfo-data", platforms: %i[windows jruby]  # timezone data en plataformas sin tzinfo nativo

group :development, :test do
  gem "dotenv-rails"           # variables de entorno desde .env
  gem "debug", platforms: %i[mri windows], require: "debug/prelude"
  gem "brakeman", require: false  # análisis estático de seguridad
  gem "sqlite3"                # base de datos para dev/test
  gem "standard", ">= 1.35.1" # linter Ruby (basado en RuboCop)
  gem "letter_opener"          # preview de emails en browser sin SMTP
end

group :development do
  gem "web-console"            # consola interactiva en páginas de error
end

group :test do
  gem "capybara"               # tests de integración / sistema
  gem "selenium-webdriver"     # driver para Capybara con browser real
end

group :production do
  gem "pg"                     # PostgreSQL para producción
end
