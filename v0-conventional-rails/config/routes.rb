Rails.application.routes.draw do
  root "products#index"

  resources :products do
    post :validate, on: :collection
    member do
      post :validate
      get "show/edit", action: :edit, as: :show_edit
    end
  end

  resource :cart, only: :show do
    get :success
    resources :items, controller: "cart_items", only: [ :create, :update, :destroy ] do
      member do
        patch :gift_wrap
        patch :save_for_later
        patch :move_to_cart
        patch :wishlist
      end
    end
    resources :wishlist_items, only: :destroy do
      post :add_to_cart, on: :member
    end
    resource :undo, only: :create, controller: "cart_undos"
    resource :promo_code, only: :update
    resource :shipping_method, only: :update
    resource :checkout, only: [ :show, :create, :update ] do
      post :validate
      get :payment
      post :pay
    end
  end

  resource :portal, only: :show do
    get :review
    get :submitted
    post :validate
    scope module: :portal do
      resources :lines, only: [ :create, :update, :destroy ]
      resource :undo, only: :create
      resource :shipping_method, only: :update
      resource :order, only: :create
    end
  end

  get "up" => "rails/health#show", as: :rails_health_check
end
