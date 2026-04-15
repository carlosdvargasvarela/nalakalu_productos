require "sidekiq/web"

Rails.application.routes.draw do
  # --- AUTENTICACIÓN Y USUARIOS ---
  devise_for :users, controllers: {
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

  # --- CORE: PRODUCTOS, VARIANTES Y CATÁLOGOS ---
  root "home#index"

  resources :products do
    member { post :update_compatibilities }
    collection { post :import }
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

  resources :properties do
    resources :property_values, shallow: true
  end

  resources :product_variant_prices, only: [:create]

  # --- ABASTECIMIENTO (SUPPLY) Y PROVEEDORES ---
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

  resources :supply_rules do
    collection do
      get :bulk_new
      post :bulk_create
    end
  end

  # --- GESTIÓN DE COMPRAS Y LOGÍSTICA ---
  resources :logistics_queries, only: [:index, :show]

  resources :supply_managements, only: [:index] do
    collection do
      post :sync_all
      post :sync_delivery
      post :create_purchase_order
    end
  end

  resources :purchase_orders do
    member do
      get "origin_order/:order_number", to: "purchase_orders#origin_order_detail",
        as: :origin_order_detail, constraints: {order_number: /[^\/]+/}
      patch :transition
      get :download_pdf
      # CORREGIDO: Usamos send_by_email para coincidir con la vista y el controlador
      post :send_by_email
    end
  end

  # --- CONFIGURACIÓN Y PROCUREMENT CONFIG ---
  resource :code_setting, only: [:edit, :update] do
    collection { patch :update_variant_type_order }
  end

  namespace :procurement_config do
    root to: "product_rules#index"

    get "products", to: "product_rules#index", as: :product_rules
    post "products/:id/rules", to: "product_rules#save", as: :save_product_rules

    get "by_variant_type", to: "by_variant_type#index", as: :by_variant_type
    post "by_variant_type/save", to: "by_variant_type#save", as: :save_by_variant_type
    get "by_variant_type/:supply_rule_id/quantities", to: "by_variant_type#quantities", as: :quantities_by_variant_type
    post "by_variant_type/:supply_rule_id/save_quantities", to: "by_variant_type#save_quantities", as: :save_quantities_by_variant_type

    get "by_product", to: "by_product#index", as: :by_product
    post "by_product/save", to: "by_product#save", as: :save_by_product

    get "consolidated", to: "consolidated#index", as: :consolidated
    post "consolidated/save", to: "consolidated#save", as: :save_consolidated
  end

  # --- PERFIL Y VENTAS ---
  get "profile", to: "profiles#show", as: :profile
  patch "profile", to: "profiles#update"

  resources :sales, only: [:new] do
    collection do
      get :variants_for_product
      get :search_products
    end
  end
end
