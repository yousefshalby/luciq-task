require "sidekiq/web"

Rails.application.routes.draw do
  # Mount Sidekiq web UI for monitoring background jobs
  mount Sidekiq::Web => "/sidekiq"
  
  # RESTful API routes
  # Applications are identified by token (in :id param)
  resources :applications, only: [:index, :create, :show, :update] do
    # Chats are identified by number (in :id param)
    # Nested under application token
    resources :chats, only: [:index, :create, :show, :update] do
      # Messages are identified by number (in :id param)
      # Nested under application token and chat number
      resources :messages, only: [:index, :create, :show, :update] do
        collection do
          # Search endpoint: GET /applications/:token/chats/:number/messages/search?query=text
          get :search
        end
      end
    end
  end

  # Health check route
  get "up", to: "rails/health#show", as: :rails_health_check
end
