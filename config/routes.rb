Rails.application.routes.draw do

  root "calendars#index"
  devise_for :users
  resources :users, only: :show do
    resources :calendars do
      resource :destroy_events, only: :destroy
      resources :particular_calendars, only: :show
    end
    resources :events, except: :index do
      resources :attendees, only: :destroy
    end
  end
  resources :attendees
  resources :events, only: :show
  namespace :api do
    resources :calendars, only: [:update, :new]
    resources :users, only: :index
    resources :events, except: [:edit, :new]
    resources :request_emails, only: :new
    resources :particular_events, only: [:index, :show]
  end
  resources :particular_calendars, only: :show
  resources :show_events, only: :show
end
