Rails.application.routes.draw do

  resources :widgets

  mount MassRecord::Engine => "/mass_record"
end
