defmodule PlausibleWeb.Router do
  use PlausibleWeb, :router
  use Plug.ErrorHandler
  use Sentry.Plug
  @two_weeks_in_seconds 60 * 60 * 24 * 14

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_flash
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :assign_device_id
    plug PlausibleWeb.SessionTimeoutPlug, timeout_after_seconds: @two_weeks_in_seconds
    plug PlausibleWeb.AuthPlug
    plug PlausibleWeb.LastSeenPlug
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
    get "/password/request-reset", AuthController, :password_reset_request_form
    post "/password/request-reset", AuthController, :password_reset_request
    get "/password/reset", AuthController, :password_reset_form
    post "/password/reset", AuthController, :password_reset
    get "/password", AuthController, :password_form
    post "/password", AuthController, :set_password
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
    get "/:website/settings", SiteController, :settings
    put "/:website/settings", SiteController, :update_settings
    delete "/:website", SiteController, :delete_site

    get "/:website", StatsController, :stats
    get "/:domain/referrers", StatsController, :referrers
    get "/:domain/pages", StatsController, :pages
    get "/:domain/countries", StatsController, :countries
    get "/:domain/operating-systems", StatsController, :operating_systems
    get "/:domain/browsers", StatsController, :browsers
  end

  scope "/api", PlausibleWeb do
    # external
    post "/page", ExternalApiController, :page
    get "/error", ExternalApiController, :error

    # internal
    get "/:domain/status", ApiController, :domain_status
  end

  def assign_device_id(conn, _opts) do
    if is_nil(Plug.Conn.get_session(conn, :device_id)) do
      Plug.Conn.put_session(conn, :device_id, UUID.uuid4())
    else
      conn
    end
  end
end
