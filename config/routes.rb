Rails.application.routes.draw do
  get  "/users/:id",                 to: "resources#user",             as: :user
  get  "/carts/:id",                 to: "resources#cart",             as: :cart
  post "/checkout-sessions/:id",     to: "resources#checkout_session", as: :checkout_session
  get  "/products/:id",              to: "resources#product",          as: :product
  get  "/orders/:id",                to: "resources#order",            as: :order
  post "/orders/:id/cancel",         to: "resources#cancel_order",     as: :cancel_order
  get  "/accounts/:id",              to: "resources#account",          as: :account
  get  "/inventory/:id",             to: "resources#inventory",        as: :inventory
  get  "/recommendations/:id",       to: "resources#recommendations",  as: :recommendations
  get  "/search",                    to: "resources#search",           as: :search
  post "/sessions",                  to: "resources#create_session",   as: :sessions
  get  "/profiles/:id/preferences",  to: "resources#preferences",      as: :preferences
  get  "/healthz",                   to: "resources#health",           as: :health
end
