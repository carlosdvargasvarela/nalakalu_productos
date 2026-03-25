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
      patch :transition
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
      post :sync_delivery
      post :create_purchase_order
    end
  end

  resources :supplier_items

  resources :supply_rules do
    collection do
      get :bulk_new
      post :bulk_create
    end
  end
end
