require 'sidekiq/web'

Rails.application.routes.draw do
  get 'up' => 'rails/health#show', as: :rails_health_check

  root 'dashboard#index'

  resources :printers do
    resources :jobs, only: %i[index]
  end

  resources :jobs, only: %i[index show update] do
    member do
      patch  :claim
      delete :claim, action: :unclaim
    end
  end

  resource :settings, only: %i[show update]

  get    '/login',                   to: 'sessions#new',     as: :login
  get    '/auth/:provider/callback', to: 'sessions#create',  as: :auth_callback
  post   '/auth/:provider/callback', to: 'sessions#create'
  get    '/auth/failure',            to: 'sessions#failure'
  delete '/logout',                  to: 'sessions#destroy', as: :logout

  constraints AdminConstraint.new do
    mount Sidekiq::Web => '/sidekiq'
  end
end
