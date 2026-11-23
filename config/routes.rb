require 'sidekiq/web'

Rails.application.routes.draw do
  get 'up' => 'rails/health#show', as: :rails_health_check

  get 'metrics', to: 'metrics#show', as: :metrics

  root 'dashboard#index'

  get 'ar', to: 'ar#show', as: :ar

  get 'printers.json', to: 'status#printers'
  get 'jobs.json', to: 'status#jobs'
  get 'events.json', to: 'status#events'

  get 'service', to: 'service_entries#index', as: :service_log
  get 'service/problems/new', to: 'service_entries#new_problem', as: :new_problem_report
  post 'service/problems', to: 'service_entries#create_problem', as: :problem_reports
  get 'service/repairs/new', to: 'service_entries#new_repair', as: :new_repair_entry
  post 'service/repairs', to: 'service_entries#create_repair', as: :repair_entries
  patch 'service/problems/:id/resolve', to: 'service_entry_resolutions#resolve', as: :resolve_problem
  patch 'service/entries/:id/reliability', to: 'service_entry_resolutions#reliability', as: :service_entry_reliability

  resources :printers do
    member do
      get :camera
      post :pause
      post :resume
      post :stop
      post :submit
      get :service, to: 'service_entries#index'
      get 'out_of_service/new', to: 'service_entries#new_outage', as: :new_out_of_service
      post :out_of_service, to: 'service_entries#out_of_service'
      delete :out_of_service, to: 'service_entries#return_to_service', as: :return_to_service
    end
    resources :jobs, only: %i[index]
  end

  resources :jobs, only: %i[index show update] do
    collection do
      get :export
    end
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
      get :reliability
    end
  end

  resource :profile, only: %i[show update]

  resources :api_tokens, only: %i[index new create show] do
    member do
      post :pause
      post :resume
      post :renew
      post :rotate
      post :revoke
    end
  end

  namespace :api, defaults: { format: :json } do
    namespace :v1 do
      get '/', to: 'docs#index'
      get 'docs', to: 'docs#show', defaults: { format: :text }
      get 'me', to: 'me#show'
    end
  end

  resources :label_printers, path: 'settings/label_printers' do
    member do
      post :test_print
    end
  end

  resource :settings, only: %i[show update]
  resource :prusa_connect_credential, only: %i[update destroy], path: 'settings/prusa_connect'

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
