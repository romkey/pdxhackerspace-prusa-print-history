require 'sidekiq/web'

Rails.application.routes.draw do
  get 'up' => 'rails/health#show', as: :rails_health_check

  root 'dashboard#index'

  get 'ar', to: 'ar#show', as: :ar

  get 'printers.json', to: 'status#printers'
  get 'jobs.json', to: 'status#jobs'
  get 'events.json', to: 'status#events'

  resources :printers do
    member do
      get :camera
    end
    resources :jobs, only: %i[index]
  end

  resources :jobs, only: %i[index show update] do
    member do
      patch  :claim
      delete :claim, action: :unclaim
      post   :clear_print
      post   :unclear_print
      post   :reprint_label
    end
  end

  resources :events, only: %i[index]

  resources :users, only: %i[index]

  resources :reports, only: %i[index] do
    collection do
      get :printers
      get :users
      get :filament
      get :attention
    end
  end

  resource :profile, only: %i[show update]

  resources :label_printers, path: 'settings/label_printers' do
    member do
      post :test_print
    end
  end

  resource :settings, only: %i[show update]

  get    '/login',                   to: 'sessions#new',          as: :login
  post   '/login/local',             to: 'sessions#create_local', as: :local_login
  get    '/auth/:provider/callback', to: 'sessions#create', as: :auth_callback
  post   '/auth/:provider/callback', to: 'sessions#create'
  get    '/auth/failure',            to: 'sessions#failure'
  delete '/logout',                  to: 'sessions#destroy', as: :logout

  constraints AdminConstraint.new do
    mount Sidekiq::Web => '/sidekiq'
  end
end
