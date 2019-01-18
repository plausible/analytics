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

    get "/", PageController, :index
    get "/onboarding", PageController, :onboarding
    post "/onboarding/site", PageController, :onboarding_create_site
    post "/login", PageController, :send_login_link
    get "/claim-login", PageController, :claim_login_link
    get "/login", PageController, :login_form
    post "/logout", PageController, :logout
    get "/sites/new", PageController, :new_site
    post "/sites", PageController, :create_site
    get "/:website/snippet", PageController, :add_snippet
    get "/:website", PageController, :analytics
  end

   scope "/api", PlausibleWeb do
     pipe_through :external_api

     post "/page", ApiController, :page
   end
end
