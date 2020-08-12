defmodule PlausibleWeb.Router do
  use PlausibleWeb, :router
  use Plug.ErrorHandler
  use Sentry.Plug
  @two_weeks_in_seconds 60 * 60 * 24 * 14

  pipeline :browser do
    plug :accepts, ["html"]
    plug PlausibleWeb.Firewall
    plug :fetch_session
    plug :fetch_flash
    plug :put_secure_browser_headers
    plug PlausibleWeb.SessionTimeoutPlug, timeout_after_seconds: @two_weeks_in_seconds
    plug PlausibleWeb.AuthPlug
    plug PlausibleWeb.LastSeenPlug
  end

  pipeline :csrf do
    plug :protect_from_forgery
  end

  pipeline :api do
    plug :accepts, ["json"]
    plug PlausibleWeb.Firewall
    plug :fetch_session
    plug PlausibleWeb.AuthPlug
  end

  pipeline :stats_api do
    plug :accepts, ["json"]
    plug PlausibleWeb.Firewall
    plug :fetch_session
  end

  if Application.get_env(:plausible, :environment) == "dev" do
    forward "/sent-emails", Bamboo.SentEmailViewerPlug
  end

  get "/js/plausible.js", PlausibleWeb.TrackerController, :plausible
  get "/js/analytics.js", PlausibleWeb.TrackerController, :plausible
  get "/js/p.js", PlausibleWeb.TrackerController, :p

  scope "/api/stats", PlausibleWeb.Api do
    pipe_through :stats_api

    get "/:domain/current-visitors", StatsController, :current_visitors
    get "/:domain/main-graph", StatsController, :main_graph
    get "/:domain/referrers", StatsController, :referrers
    get "/:domain/goal/referrers", StatsController, :referrers_for_goal
    get "/:domain/referrers/:referrer", StatsController, :referrer_drilldown
    get "/:domain/goal/referrers/:referrer", StatsController, :referrer_drilldown_for_goal
    get "/:domain/pages", StatsController, :pages
    get "/:domain/entry-pages", StatsController, :entry_pages
    get "/:domain/countries", StatsController, :countries
    get "/:domain/browsers", StatsController, :browsers
    get "/:domain/operating-systems", StatsController, :operating_systems
    get "/:domain/screen-sizes", StatsController, :screen_sizes
    get "/:domain/conversions", StatsController, :conversions
  end

  scope "/api", PlausibleWeb do
    pipe_through :api

    post "/event", Api.ExternalController, :event
    get "/error", Api.ExternalController, :error
    get "/health", Api.ExternalController, :health

    post "/paddle/webhook", Api.PaddleController, :webhook

    get "/:domain/status", Api.InternalController, :domain_status
    get "/sites", Api.InternalController, :sites
  end

  scope "/", PlausibleWeb do
    pipe_through :browser

    get "/register", AuthController, :register_form
    post "/register", AuthController, :register
    get "/claim-activation", AuthController, :claim_activation_link
    get "/login", AuthController, :login_form
    post "/login", AuthController, :login
    get "/password/request-reset", AuthController, :password_reset_request_form
    post "/password/request-reset", AuthController, :password_reset_request
    get "/password/reset", AuthController, :password_reset_form
    post "/password/reset", AuthController, :password_reset
  end

  scope "/", PlausibleWeb do
    pipe_through [:browser, :csrf]

    get "/password", AuthController, :password_form
    post "/password", AuthController, :set_password
    post "/logout", AuthController, :logout
    get "/settings", AuthController, :user_settings
    put "/settings", AuthController, :save_settings
    delete "/me", AuthController, :delete_me

    get "/auth/google/callback", AuthController, :google_auth_callback

    get "/", PageController, :index

    get "/billing/change-plan", BillingController, :change_plan_form
    get "/billing/change-plan/preview/:plan_id", BillingController, :change_plan_preview
    post "/billing/change-plan/:new_plan_id", BillingController, :change_plan
    get "/billing/upgrade", BillingController, :upgrade
    get "/billing/success", BillingController, :success

    get "/sites", SiteController, :index
    get "/sites/new", SiteController, :new
    post "/sites", SiteController, :create_site
    post "/sites/:website/make-public", SiteController, :make_public
    post "/sites/:website/make-private", SiteController, :make_private
    post "/sites/:website/weekly-report/enable", SiteController, :enable_weekly_report
    post "/sites/:website/weekly-report/disable", SiteController, :disable_weekly_report
    post "/sites/:website/weekly-report/recipients", SiteController, :add_weekly_report_recipient

    delete "/sites/:website/weekly-report/recipients/:recipient",
           SiteController,
           :remove_weekly_report_recipient

    post "/sites/:website/monthly-report/enable", SiteController, :enable_monthly_report
    post "/sites/:website/monthly-report/disable", SiteController, :disable_monthly_report

    post "/sites/:website/monthly-report/recipients",
         SiteController,
         :add_monthly_report_recipient

    delete "/sites/:website/monthly-report/recipients/:recipient",
           SiteController,
           :remove_monthly_report_recipient

    get "/sites/:website/shared-links/new", SiteController, :new_shared_link
    post "/sites/:website/shared-links", SiteController, :create_shared_link
    delete "/sites/:website/shared-links/:slug", SiteController, :delete_shared_link

    get "/sites/:website/custom-domains/new", SiteController, :new_custom_domain
    get "/sites/:website/custom-domains/dns-setup", SiteController, :custom_domain_dns_setup
    get "/sites/:website/custom-domains/snippet", SiteController, :custom_domain_snippet
    post "/sites/:website/custom-domains", SiteController, :add_custom_domain
    delete "/sites/:website/custom-domains/:id", SiteController, :delete_custom_domain

    get "/sites/:website/weekly-report/unsubscribe", UnsubscribeController, :weekly_report
    get "/sites/:website/monthly-report/unsubscribe", UnsubscribeController, :monthly_report

    get "/:website/snippet", SiteController, :add_snippet
    get "/:website/settings", SiteController, :settings
    get "/:website/goals", SiteController, :goals
    get "/:website/goals/new", SiteController, :new_goal
    post "/:website/goals", SiteController, :create_goal
    delete "/:website/goals/:id", SiteController, :delete_goal
    put "/:website/settings", SiteController, :update_settings
    put "/:website/settings/google", SiteController, :update_google_auth
    delete "/:website/settings/google", SiteController, :delete_google_auth
    delete "/:website", SiteController, :delete_site
    delete "/:website/stats", SiteController, :reset_stats

    get "/share/:slug", StatsController, :shared_link
    post "/share/:slug/authenticate", StatsController, :authenticate_shared_link
    get "/:domain/visitors.csv", StatsController, :csv_export
    get "/:domain/*path", StatsController, :stats
  end
end
