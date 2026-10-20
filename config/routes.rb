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
    member { post :update_compatibilities }
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
    member { patch :move_to_type }
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
    collection { post :import }
  end
  resources :supplier_links, only: [:create, :destroy]

  # Revisión: marca aprobado / requiere cambios sobre cualquier registro revisable
  get "reviews/next", to: "reviews#next", as: :next_review
  resources :reviews, only: [:create]

  # Problemas de calidad de datos antes de migrar a Odoo
  get "quality", to: "quality#index", as: :quality

  # Descarga de los CSV de importación para Odoo
  get "odoo_exports", to: "odoo_exports#index", as: :odoo_exports
  get "odoo_exports/:file", to: "odoo_exports#show", as: :odoo_export, constraints: {file: /[\w.]+/}

  get "profile", to: "profiles#show", as: :profile
  patch "profile", to: "profiles#update"
end
