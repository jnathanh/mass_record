Rails.application.routes.draw do

  resources :sql_server_widgets

  resources :widgets

  resources :mysql_widgets

  mount MassRecord::Engine => "/mass_record"
end
