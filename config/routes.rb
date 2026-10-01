require Rails.root.join("lib", "ores_app", "routes")

Rails.application.routes.draw do
  OresApp::Routes.each do |route|
    match route.path,
      via: route.method.downcase.to_sym,
      to: "resources#dispatch",
      as: route.name.to_sym
  end
end
