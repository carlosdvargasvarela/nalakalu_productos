# Pin npm packages by running ./bin/importmap

pin "application"
pin "@hotwired/turbo-rails", to: "turbo.min.js"
pin "@hotwired/stimulus", to: "stimulus.min.js"
pin "@hotwired/stimulus-loading", to: "stimulus-loading.js"
pin_all_from "app/javascript/controllers", under: "controllers"
pin "bootstrap", to: "bootstrap.bundle.min.js"
pin "tom-select", to: "https://cdn.jsdelivr.net/npm/tom-select@2.4.3/dist/esm/tom-select.complete.min.js"
