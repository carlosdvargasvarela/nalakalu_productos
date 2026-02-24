source "https://rubygems.org"

gem "rails", "~> 7.2.3"
gem "sprockets-rails"
gem "puma", ">= 5.0"
gem "importmap-rails"
gem "turbo-rails"
gem "stimulus-rails"
gem "cssbundling-rails"
gem "jbuilder"

gem "tzinfo-data", platforms: %i[windows jruby]
gem "bootsnap", require: false
gem "devise"
gem "sidekiq"
gem "redis", "~> 5.0"
gem "csv"
gem "faraday"

group :development, :test do
  gem "dotenv-rails"
  gem "debug", platforms: %i[mri windows], require: "debug/prelude"
  gem "brakeman", require: false
  gem "sqlite3"
  gem "standard", ">= 1.35.1"
end

group :development do
  gem "web-console"
end

group :test do
  gem "capybara"
  gem "selenium-webdriver"
end

group :production do
  gem "pg"
end
