# frozen_string_literal: true

Rails.application.routes.draw do
  get "/users/:id", to: "users/show/endpoint#show", as: :user
  get "/users/:id/activity", to: "users/activity/endpoint#show", as: :user_activity
  get "/carts/:id", to: "carts/show/endpoint#show", as: :cart
  post "/checkout-sessions/:id", to: "checkout_sessions/create/endpoint#create", as: :checkout_session
  get "/products/:id", to: "products/show/endpoint#show", as: :product
  get "/orders/:id", to: "orders/show/endpoint#show", as: :order
  get "/orders/:id/receipt", to: "orders/receipt/endpoint#show", as: :order_receipt
  post "/orders/:id/cancel", to: "orders/cancel/endpoint#cancel", as: :cancel_order
  get "/accounts/:id", to: "accounts/show/endpoint#show", as: :account
  get "/inventory/:id", to: "inventory/show/endpoint#show", as: :inventory
  get "/recommendations/:id", to: "recommendations/show/endpoint#show", as: :recommendations
  get "/search", to: "search/index/endpoint#index", as: :search
  post "/sessions", to: "sessions/create/endpoint#create", as: :create_session
  get "/profiles/:id/preferences", to: "profiles/preferences/show/endpoint#show", as: :preferences
  get "/healthz", to: "healthz/show/endpoint#show", as: :health
end
