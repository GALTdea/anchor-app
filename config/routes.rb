Rails.application.routes.draw do
  devise_for :users

  get "home", to: "home#index", as: :home

  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html
  resources :users, only: %i[edit update destroy]
  namespace :admin do
    root "dashboard#show"

    resources :assessment_templates, only: %i[index show new create edit update] do
      member do
        get :preview
        post :publish
        post :new_version
        post :set_as_onboarding
      end
    end
  end

  scope :onboarding, as: :onboarding do
    resource :session, only: %i[new create show], controller: "onboarding/sessions"
    resource :child, only: %i[show update], controller: "onboarding/children"
    resource :assessment, only: %i[show update], controller: "onboarding/assessments"
    resource :account, only: %i[show create], controller: "onboarding/accounts"
    resource :results, only: %i[show], controller: "onboarding/results"
  end

  resources :spaces do
    resources :users, only: %i[index new create edit update destroy], controller: "spaces/users"
    resources :roles, controller: "spaces/roles"
    resources :subscriptions, controller: "spaces/subscriptions"
    resources :child_profiles, controller: "spaces/child_profiles" do
      resources :assessments, only: %i[index new create show destroy], controller: "child_profiles/assessments" do
        post :start_onboarding, on: :collection

        resource :response, only: %i[show edit update],
          controller: "child_profiles/assessment_responses",
          as: :assessment_response
      end

      resource :current_profile, only: %i[show], controller: "child_profiles/current_profiles"
      resources :recommendations, only: %i[index show], controller: "child_profiles/recommendations"
    end
  end

  resource :setup, only: %i[edit update]

  # Error pages
  %w[404 422 500].each do |code|
    get code, to: "errors#show", code:
  end

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # Defines the root path route ("/")
  root "application#landing"
end
