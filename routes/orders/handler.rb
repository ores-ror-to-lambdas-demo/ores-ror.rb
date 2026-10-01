# frozen_string_literal: true

OresApp::Routes.register_group(
  name: "orders",
  source: "routes/orders/handler.rb"
) do |route, request|
  case route.name
  when "order", "cancel_order"
    route.call(request)
  else
    raise ArgumentError, "route #{route.name.inspect} is not in orders group"
  end
end
