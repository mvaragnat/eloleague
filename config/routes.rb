# frozen_string_literal: true

Rails.application.routes.draw do
  # Restrict Avo to authenticated admins only
  authenticate :admin do
    mount_avo
  end
  scope '(:locale)', locale: /en|fr/ do
    devise_for :users, controllers: { sessions: 'users/sessions' }
    devise_for :admins, skip: %i[registrations passwords], controllers: { sessions: 'devise/sessions' }
    root to: 'pages#home'

    # Devise handles sessions/registrations/passwords

    # Elo
    get 'elo', to: 'elo#index', as: :elo

    # Dashboard
    resource :dashboard, only: :show

    # Game events and factions
    namespace :game do
      resources :events, only: %i[new create show]
      resources :factions, only: %i[index]
    end

    # Users search (used by player search UI)
    get 'users/search', to: 'users#search', as: :users_search
    resources :users, only: %i[index]

    # Contact
    resources :contacts, only: %i[new create]

    # Tournaments
    resources :tournaments do
      member do
        post :register
        delete :unregister
        post :check_in
        post :lock_registration
        post :next_round
        post :finalize
      end

      namespace :tournament do
        resources :rounds, only: %i[index show]
        resources :matches, only: %i[index show update new create] do
          member do
            patch :reassign
          end
        end
        resources :registrations, only: %i[show update]
      end
    end
  end
end
