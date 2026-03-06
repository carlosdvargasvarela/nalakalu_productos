require "sidekiq/web"
Rails.application.routes.draw do
  devise_for :users

  authenticate :user, lambda { |u| u.role == "admin" } do
    mount Sidekiq::Web => "/sidekiq"
  end

  root "home#index"

  resources :sales, only: [:new] do
    collection do
      get :variants_for_product
      get :search_products
    end
  end

  resources :providers do
    collection do
      post :import
    end
  end

  resources :variant_types do
    collection do
      post :import
    end
  end

  resources :variants

  resources :products do
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
end
