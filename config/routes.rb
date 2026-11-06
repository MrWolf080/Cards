Rails.application.routes.draw do
  mount ActionCable.server => "/cable"
  namespace :api do
    namespace :v1 do
      resource :session, only: [:create, :destroy]
      resource :registration, only: [:create]
      resource :current_user, only: [:show]
      resource :profile, only: [:show, :update]
      get 'dashboard', to: 'dashboard#show'
      resources :decks, only: [:index, :show, :create, :destroy] do
        resources :cards, only: [:index, :create, :destroy]
        get 'suggestions', to: 'cards#suggestions'

        get 'study', to: 'study#index'
        post 'study/answer', to: 'study#answer'
        post 'study/finish', to: 'study#finish'
        get 'quiz', to: 'study#quiz'
      end
      get 'stats', to: 'stats#index'
    end
  end
end
