# frozen_string_literal: true

Rails.application.routes.draw do
  get "/users/:id", to: "users/show/endpoint#show", as: :user, defaults: { ores_middleware: "request_id,users_show_header" }
  get "/users/:id/activity", to: "users/activity/endpoint#show", as: :user_activity, defaults: { ores_middleware: "request_id" }
  get "/carts/:id", to: "carts/show/endpoint#show", as: :cart, defaults: { ores_middleware: "request_id" }
  post "/checkout-sessions/:id", to: "checkout_sessions/create/endpoint#create", as: :checkout_session, defaults: { ores_middleware: "request_id" }
  get "/products/:id", to: "products/show/endpoint#show", as: :product, defaults: { ores_middleware: "request_id" }
  get "/orders/:id", to: "orders/show/endpoint#show", as: :order, defaults: { ores_middleware: "request_id" }
  get "/orders/:id/receipt", to: "orders/receipt/endpoint#show", as: :order_receipt, defaults: { ores_middleware: "request_id" }
  post "/orders/:id/cancel", to: "orders/cancel/endpoint#cancel", as: :cancel_order, defaults: { ores_middleware: "request_id,order_cancel_header" }
  get "/accounts/:id", to: "accounts/show/endpoint#show", as: :account, defaults: { ores_middleware: "request_id" }
  get "/inventory/:id", to: "inventory/show/endpoint#show", as: :inventory, defaults: { ores_middleware: "request_id" }
  get "/recommendations/:id", to: "recommendations/show/endpoint#show", as: :recommendations, defaults: { ores_middleware: "request_id" }
  get "/search", to: "search/index/endpoint#index", as: :search, defaults: { ores_middleware: "request_id,search_header" }
  post "/sessions", to: "sessions/create/endpoint#create", as: :create_session, defaults: { ores_middleware: "request_id" }
  get "/profiles/:id/preferences", to: "profiles/preferences/show/endpoint#show", as: :preferences, defaults: { ores_middleware: "request_id" }
  get "/healthz", to: "healthz/show/endpoint#show", as: :health, defaults: { ores_middleware: "request_id" }
end
