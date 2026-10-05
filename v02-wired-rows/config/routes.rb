Rails.application.routes.draw do
  root "home#show"

  resources :products do
    collection { post :validate }
    member { post :add_to_cart }
  end

  resource :cart, only: :show do
    resources :items, only: [ :update, :destroy ], controller: "cart_items" do
      member do
        patch :gift_wrap
        post :save
        post :wishlist
      end
    end
    resource :undo, only: :create, controller: "cart_undos" do
      post :expire
    end
    resources :saved_items, only: [] do
      post :move, on: :member
    end
    resources :wishlist_items, only: :destroy do
      post :add_to_cart, on: :member
    end
    post :promo, to: "cart_pricing#promo"
    patch :shipping, to: "cart_pricing#shipping"
  end

  scope "cart", as: "cart" do
    resource :checkout, only: [ :create, :show ] do
      post :validate
      patch :address
      post :edit_address
      post :pay
    end
    get "checkout/:step", to: "checkouts#show", as: :checkout_step
    get "success", to: "cart_successes#show", as: :success
  end

  resource :portal, only: :show do
    post :review
    post :edit_lines
    post :validate
    post :submit
    resources :lines, only: [ :create, :update, :destroy ], controller: "portal_lines"
    resource :undo, only: :create, controller: "portal_undos" do
      post :expire
    end
  end
  get "portal/:step", to: "portals#show", as: :portal_step

  get "up" => "rails/health#show", as: :rails_health_check
end
