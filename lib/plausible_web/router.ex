defmodule PlausibleWeb.Router do
  use PlausibleWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_flash
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :external_api do
    plug :accepts, ["text/plain"]
  end

  pipeline :api do
    plug :accepts, ["application/json"]
  end

  if Mix.env == :dev do
    forward "/sent-emails", Bamboo.SentEmailViewerPlug
  end

  scope "/", PlausibleWeb do
    pipe_through :browser

    get "/onboarding", AuthController, :onboarding
    get "/login", AuthController, :login_form
    post "/login", AuthController, :send_login_link
    post "/logout", AuthController, :logout
    get "/claim-login", AuthController, :claim_login_link

    get "/", PageController, :index
    get "/sites/new", PageController, :new_site
    post "/sites", PageController, :create_site
    get "/privacy", PageController, :privacy
    get "/terms", PageController, :terms
    get "/:website/snippet", PageController, :add_snippet
    get "/:website", PageController, :analytics
  end

   scope "/api", PlausibleWeb do
     pipe_through :external_api

     post "/page", ApiController, :page
   end
end
