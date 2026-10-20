require "sidekiq/web"

# App enfocada en revisar el catálogo antes de subirlo a Odoo.
# Los módulos de inventario, compras, abastecimiento, salas, ventas, etc. siguen en el código
# pero sin rutas (ver git history para restaurarlas).
Rails.application.routes.draw do
  devise_for :users, skip: [:registrations], controllers: {
    omniauth_callbacks: "users/omniauth_callbacks"
  }

  authenticate :user, lambda { |u| u.role == "admin" } do
    mount Sidekiq::Web => "/sidekiq"
  end

  resources :users do
    member do
      get :edit_password
      patch :update_password
    end
  end

  root "home#index"

  resources :products do
    member do
      post :update_compatibilities
      post :duplicate
    end
    collection do
      post :import
      patch :bulk_activate
      patch :bulk_deactivate
    end
  end

  resources :variant_types do
    member { get :variants, defaults: {format: :json} }
    collection do
      post :import
      patch :bulk_move
      patch :bulk_assign
    end
  end

  resources :variants do
    member do
      patch :move_to_type
      post :duplicate
    end
    collection { post :import }
  end

  resources :families do
    member do
      post :assign_products
      delete :unassign_product
    end
    collection { post :bulk_unassign }
  end

  resources :providers do
    member do
      post :assign_variant
      delete :unassign_variant
    end
    collection { post :import }
  end

  resources :supplier_items do
    member { post :duplicate }
    collection { post :import }
  end
  resources :supplier_links, only: [:create, :destroy]

  # Revisión: marca aprobado / requiere cambios sobre cualquier registro revisable
  get "reviews/next", to: "reviews#next", as: :next_review
  resources :reviews, only: [:index, :create] # index = pendientes de corrección

  # Eliminar con confirmación (conteo de lo que se pierde) u ocultar en su lugar
  scope constraints: {kind: /product|variant|variant_type|family|provider|supplier_item/} do
    get "eliminar/:kind/:id", to: "deletions#new", as: :confirm_delete
    delete "eliminar/:kind/:id", to: "deletions#destroy"
    patch "ocultar/:kind/:id", to: "deletions#hide", as: :hide_record
  end

  # Edición rápida de un campo desde las listas
  patch "rapido/:kind/:id", to: "quick_edits#update", as: :quick_edit, constraints: {kind: /product|variant|supplier_item|provider|family|variant_type/}

  # Carga masiva de precios (CSV o Excel)
  get "precios", to: "price_imports#new", as: :price_imports
  get "precios/plantilla", to: "price_imports#template", as: :price_template
  post "precios/vista_previa", to: "price_imports#preview", as: :price_preview
  post "precios/aplicar", to: "price_imports#apply", as: :price_apply

  # Historial de cambios y deshacer
  get "historial", to: "changes#index", as: :changes
  post "historial/:id/deshacer", to: "changes#undo", as: :undo_change

  # Problemas de calidad de datos antes de migrar a Odoo
  get "quality", to: "quality#index", as: :quality

  # Descarga de los CSV de importación para Odoo
  get "odoo_exports", to: "odoo_exports#index", as: :odoo_exports
  get "odoo_exports/:file", to: "odoo_exports#show", as: :odoo_export, constraints: {file: /[\w.]+/}

  # Reorganizar: mover productos / variantes / piezas entre grupos (o a un grupo nuevo = duplicar el grupo)
  get "reorganizar/:kind/:id", to: "groupings#new", as: :reorganize, constraints: {kind: /family|variant_type|provider/}
  post "reorganizar/:kind/:id", to: "groupings#create", constraints: {kind: /family|variant_type|provider/}

  get "profile", to: "profiles#show", as: :profile
  patch "profile", to: "profiles#update"
end
