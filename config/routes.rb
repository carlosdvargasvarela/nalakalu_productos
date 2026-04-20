require "sidekiq/web"

Rails.application.routes.draw do
  # --- AUTENTICACIÓN Y USUARIOS ---
  # skip: [:registrations] evita que Devise registre POST /users → RegistrationsController#create
  # lo que causaba que el formulario admin de creación de usuarios fuera interceptado por Devise
  devise_for :users, skip: [:registrations], controllers: {
    omniauth_callbacks: "users/omniauth_callbacks"
  }

  # Sidekiq Web UI — solo accesible para admins autenticados
  authenticate :user, lambda { |u| u.role == "admin" } do
    mount Sidekiq::Web => "/sidekiq"
  end

  # Gestión de usuarios (solo admin, ver UsersController + before_action :authorize_admin!)
  resources :users do
    member do
      get :edit_password    # GET  /users/:id/edit_password
      patch :update_password # PATCH /users/:id/update_password
    end
  end

  # --- CORE: PRODUCTOS, VARIANTES Y CATÁLOGOS ---
  root "home#index"

  # Productos: compatibilidades por member, importación por collection
  resources :products do
    member { post :update_compatibilities }
    collection { post :import }
  end

  # Tipos de variante: variantes en JSON por member, operaciones bulk por collection
  resources :variant_types do
    member { get :variants, defaults: {format: :json} }
    collection do
      post :import
      patch :bulk_move
      patch :bulk_assign
    end
  end

  # Variantes individuales: mover de tipo por member, importación por collection
  resources :variants do
    member { patch :move_to_type }
    collection { post :import }
  end

  # Familias de productos: asignación/desasignación de productos
  resources :families do
    member do
      post :assign_products   # POST   /families/:id/assign_products
      delete :unassign_product  # DELETE /families/:id/unassign_product
    end
    collection { post :bulk_unassign } # POST /families/bulk_unassign
  end

  # Propiedades y sus valores (shallow: valores accesibles sin el prefijo /properties/:id)
  resources :properties do
    resources :property_values, shallow: true
  end

  # Precios por variante de producto (solo creación)
  resources :product_variant_prices, only: [:create]

  # --- ABASTECIMIENTO (SUPPLY) Y PROVEEDORES ---

  # Proveedores: asignación de variantes por member, importación por collection
  resources :providers do
    member do
      post :assign_variant   # POST   /providers/:id/assign_variant
      delete :unassign_variant # DELETE /providers/:id/unassign_variant
    end
    collection { post :import }
  end

  # Items de proveedor (SupplierItem): importación por collection
  resources :supplier_items do
    collection { post :import }
  end

  # Reglas de abastecimiento: creación individual y bulk
  resources :supply_rules do
    collection do
      get :bulk_new    # GET  /supply_rules/bulk_new
      post :bulk_create # POST /supply_rules/bulk_create
    end
  end

  # --- GESTIÓN DE COMPRAS Y LOGÍSTICA ---

  # Consultas a la API de logística (solo lectura)
  resources :logistics_queries, only: [:index, :show]

  # Gestión de abastecimiento: sincronización y creación de órdenes de compra
  resources :supply_managements, only: [:index] do
    collection do
      post :sync_all            # POST /supply_managements/sync_all
      post :sync_delivery       # POST /supply_managements/sync_delivery
      post :create_purchase_order # POST /supply_managements/create_purchase_order
    end
  end

  # Órdenes de compra: transiciones de estado, PDF, email y detalle de origen
  resources :purchase_orders do
    member do
      # Detalle de orden de origen — permite "/" en el número de orden
      get "origin_order/:order_number",
        to: "purchase_orders#origin_order_detail",
        as: :origin_order_detail,
        constraints: {order_number: /[^\/]+/}

      patch :transition    # PATCH /purchase_orders/:id/transition
      get :download_pdf  # GET   /purchase_orders/:id/download_pdf
      post :send_by_email # POST  /purchase_orders/:id/send_by_email
    end
  end

  # --- CONFIGURACIÓN GENERAL ---

  # Configuración de códigos (singleton resource — no tiene :id)
  resource :code_setting, only: [:edit, :update] do
    collection { patch :update_variant_type_order }
  end

  # --- PROCUREMENT CONFIG (namespace) ---
  # Todas las rutas bajo /procurement_config/...
  namespace :procurement_config do
    root to: "product_rules#index"

    # Reglas por producto
    get "products", to: "product_rules#index", as: :product_rules
    post "products/:id/rules", to: "product_rules#save", as: :save_product_rules

    # Reglas globales por tipo de variante + cantidades por producto
    get "by_variant_type", to: "by_variant_type#index", as: :by_variant_type
    post "by_variant_type/save", to: "by_variant_type#save", as: :save_by_variant_type
    get "by_variant_type/:supply_rule_id/quantities", to: "by_variant_type#quantities", as: :quantities_by_variant_type
    post "by_variant_type/:supply_rule_id/save_quantities", to: "by_variant_type#save_quantities", as: :save_quantities_by_variant_type

    # Reglas específicas por producto
    get "by_product", to: "by_product#index", as: :by_product
    post "by_product/save", to: "by_product#save", as: :save_by_product

    # Reglas consolidadas (escenario fibras / multi-variante → 1 item)
    get "consolidated", to: "consolidated#index", as: :consolidated
    post "consolidated/save", to: "consolidated#save", as: :save_consolidated
  end

  # --- PERFIL DE USUARIO ---
  get "profile", to: "profiles#show", as: :profile
  patch "profile", to: "profiles#update"

  # --- VENTAS ---
  # Solo new + helpers de búsqueda de productos y variantes (para el formulario de venta)
  resources :sales, only: [:new] do
    collection do
      get :variants_for_product # GET /sales/variants_for_product
      get :search_products      # GET /sales/search_products
    end
  end
end
