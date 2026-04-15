require "sidekiq/web"
Rails.application.routes.draw do
  devise_for :users

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

  resources :sales, only: [:new] do
    collection do
      get :variants_for_product
      get :search_products
    end
  end

  resources :providers do
    member do
      post :assign_variant
      delete :unassign_variant
    end
    collection do
      post :import
    end
  end

  resources :variant_types do
    member do
      get :variants, defaults: {format: :json}
    end
    collection do
      post :import
      patch :bulk_move
      patch :bulk_assign
    end
  end

  resources :variants do
    member do
      patch :move_to_type
    end
    collection do
      post :import
    end
  end

  resources :products do
    member do
      post :update_compatibilities
    end
    collection do
      post :import
    end
  end

  resources :logistics_queries, only: [:index, :show]

  resources :families do
    member do
      post :assign_products
      delete :unassign_product
    end
    collection do
      post :bulk_unassign
    end
  end

  resources :purchase_orders do
    member do
      get "origin_order/:order_number", to: "purchase_orders#origin_order_detail",
        as: :origin_order_detail, constraints: {order_number: /[^\/]+/}
      patch :transition
      get :download_pdf
      post :send_email
    end
  end

  resources :product_variant_prices, only: [:create]

  resources :properties do
    resources :property_values, shallow: true
  end

  resource :code_setting, only: [:edit, :update] do
    collection do
      patch :update_variant_type_order
    end
  end

  resources :supply_managements, only: [:index] do
    collection do
      post :sync_all
      post :sync_delivery
      post :create_purchase_order
    end
  end

  resources :supplier_items do
    collection do
      post :import
    end
  end

  resources :supply_rules do
    collection do
      get :bulk_new
      post :bulk_create
    end
  end

  namespace :procurement_config do
    root to: "product_rules#index"
    # Nuevo workspace unificado por producto
    get "products", to: "product_rules#index", as: :product_rules
    post "products/:id/rules", to: "product_rules#save", as: :save_product_rules

    # Rutas legacy — mantener hasta confirmar migración completa
    get "by_variant_type", to: "by_variant_type#index", as: :by_variant_type
    post "by_variant_type/save", to: "by_variant_type#save", as: :save_by_variant_type
    get "by_variant_type/:supply_rule_id/quantities", to: "by_variant_type#quantities", as: :quantities_by_variant_type
    post "by_variant_type/:supply_rule_id/save_quantities", to: "by_variant_type#save_quantities", as: :save_quantities_by_variant_type

    get "by_product", to: "by_product#index", as: :by_product
    post "by_product/save", to: "by_product#save", as: :save_by_product

    get "consolidated", to: "consolidated#index", as: :consolidated
    post "consolidated/save", to: "consolidated#save", as: :save_consolidated
  end
end
