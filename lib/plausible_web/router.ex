defmodule PlausibleWeb.Router do
  use PlausibleWeb, :router
  use Plug.ErrorHandler
  use Sentry.Plug

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_flash
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug PlausibleWeb.AuthPlug
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

    get "/register", AuthController, :register_form
    post "/register", AuthController, :register
    get "/claim-activation", AuthController, :claim_activation_link
    get "/login", AuthController, :login_form
    post "/login", AuthController, :login
    get "/claim-login", AuthController, :claim_login_link
    post "/logout", AuthController, :logout
    get "/settings", AuthController, :user_settings
    put "/settings", AuthController, :save_settings
    delete "/me", AuthController, :delete_me

    get "/", PageController, :index
    get "/privacy", PageController, :privacy
    get "/terms", PageController, :terms
    get "/feedback", PageController, :feedback
    post "/feedback", PageController, :submit_feedback

    get "/sites/new", SiteController, :new
    post "/sites", SiteController, :create_site
    get "/:website/snippet", SiteController, :add_snippet
    get "/:website", SiteController, :analytics
  end

  scope "/api", PlausibleWeb do
    pipe_through :external_api

    post "/page", ApiController, :page
    get "/error", ApiController, :error
  end
end
