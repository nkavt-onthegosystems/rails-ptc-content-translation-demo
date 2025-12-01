Rails.application.routes.draw do
  resources :posts
  namespace :api, defaults: { format: :json } do
    post "posts/:post_id/callback", to: "callbacks#create", as: :post_callback
  end
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Defines the root path route ("/")
  # root "articles#index"
end
