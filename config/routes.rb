Rails.application.routes.draw do
  devise_for :users

  root "home#index"

  resources :sales, only: [:new] do
    collection do
      get :variants_for_product
    end
  end

  resources :providers
  resources :variant_types
  resources :variants
  resources :products
end