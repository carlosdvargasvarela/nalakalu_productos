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
end
