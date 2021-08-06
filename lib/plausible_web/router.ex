defmodule PlausibleWeb.Router do
  use PlausibleWeb, :router
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

  pipeline :shared_link do
    plug :accepts, ["html"]
    plug :put_secure_browser_headers
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

  pipeline :internal_stats_api do
    plug :accepts, ["json"]
    plug PlausibleWeb.Firewall
    plug :fetch_session
    plug PlausibleWeb.AuthorizeSiteAccess
  end

  pipeline :public_api do
    plug :accepts, ["json"]
    plug PlausibleWeb.Firewall
  end

  if Application.get_env(:plausible, :environment) == "dev" do
    forward "/sent-emails", Bamboo.SentEmailViewerPlug
  end

  use Kaffy.Routes, scope: "/crm", pipe_through: [PlausibleWeb.CRMAuthPlug]

  scope "/api/stats", PlausibleWeb.Api do
    pipe_through :internal_stats_api

    get "/:domain/current-visitors", StatsController, :current_visitors
    get "/:domain/main-graph", StatsController, :main_graph
    get "/:domain/sources", StatsController, :sources
    get "/:domain/utm_mediums", StatsController, :utm_mediums
    get "/:domain/utm_sources", StatsController, :utm_sources
    get "/:domain/utm_campaigns", StatsController, :utm_campaigns
    get "/:domain/referrers/:referrer", StatsController, :referrer_drilldown
    get "/:domain/pages", StatsController, :pages
    get "/:domain/entry-pages", StatsController, :entry_pages
    get "/:domain/exit-pages", StatsController, :exit_pages
    get "/:domain/countries", StatsController, :countries
    get "/:domain/subdivisions1", StatsController, :subdivisions1
    get "/:domain/subdivisions2", StatsController, :subdivisions2
    get "/:domain/cities", StatsController, :cities
    get "/:domain/browsers", StatsController, :browsers
    get "/:domain/browser-versions", StatsController, :browser_versions
    get "/:domain/operating-systems", StatsController, :operating_systems
    get "/:domain/operating-system-versions", StatsController, :operating_system_versions
    get "/:domain/screen-sizes", StatsController, :screen_sizes
    get "/:domain/conversions", StatsController, :conversions
    get "/:domain/property/:prop_name", StatsController, :prop_breakdown
    get "/:domain/suggestions/:filter_name", StatsController, :filter_suggestions
  end

  scope "/api/v1/stats", PlausibleWeb.Api do
    pipe_through [:public_api, PlausibleWeb.AuthorizeStatsApiPlug]

    get "/realtime/visitors", ExternalStatsController, :realtime_visitors
    get "/aggregate", ExternalStatsController, :aggregate
    get "/breakdown", ExternalStatsController, :breakdown
    get "/timeseries", ExternalStatsController, :timeseries
  end

  scope "/api/v1/sites", PlausibleWeb.Api do
    pipe_through [:public_api, PlausibleWeb.AuthorizeSitesApiPlug]

    post "/", ExternalSitesController, :create_site
    put "/shared-links", ExternalSitesController, :find_or_create_shared_link
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
    pipe_through [:browser, :csrf]

    get "/register", AuthController, :register_form
    post "/register", AuthController, :register
    get "/register/invitation/:invitation_id", AuthController, :register_from_invitation_form
    post "/register/invitation/:invitation_id", AuthController, :register_from_invitation
    get "/activate", AuthController, :activate_form
    post "/activate/request-code", AuthController, :request_activation_code
    post "/activate", AuthController, :activate
    get "/login", AuthController, :login_form
    post "/login", AuthController, :login
    get "/password/request-reset", AuthController, :password_reset_request_form
    post "/password/request-reset", AuthController, :password_reset_request
    get "/password/reset", AuthController, :password_reset_form
    post "/password/reset", AuthController, :password_reset
  end

  scope "/", PlausibleWeb do
    pipe_through [:shared_link]

    get "/share/:slug", StatsController, :shared_link
    post "/share/:slug/authenticate", StatsController, :authenticate_shared_link
  end

  scope "/", PlausibleWeb do
    pipe_through [:browser, :csrf]

    get "/password", AuthController, :password_form
    post "/password", AuthController, :set_password
    get "/logout", AuthController, :logout
    get "/settings", AuthController, :user_settings
    put "/settings", AuthController, :save_settings
    delete "/me", AuthController, :delete_me
    get "/settings/api-keys/new", AuthController, :new_api_key
    post "/settings/api-keys", AuthController, :create_api_key
    delete "/settings/api-keys/:id", AuthController, :delete_api_key

    get "/auth/google/callback", AuthController, :google_auth_callback

    get "/", PageController, :index

    get "/billing/change-plan", BillingController, :change_plan_form
    get "/billing/change-plan/preview/:plan_id", BillingController, :change_plan_preview
    post "/billing/change-plan/:new_plan_id", BillingController, :change_plan
    get "/billing/upgrade", BillingController, :upgrade
    get "/billing/upgrade/:plan_id", BillingController, :upgrade_to_plan
    get "/billing/upgrade-success", BillingController, :upgrade_success

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

    post "/sites/:website/spike-notification/enable", SiteController, :enable_spike_notification
    post "/sites/:website/spike-notification/disable", SiteController, :disable_spike_notification
    put "/sites/:website/spike-notification", SiteController, :update_spike_notification

    post "/sites/:website/spike-notification/recipients",
         SiteController,
         :add_spike_notification_recipient

    delete "/sites/:website/spike-notification/recipients/:recipient",
           SiteController,
           :remove_spike_notification_recipient

    get "/sites/:website/shared-links/new", SiteController, :new_shared_link
    post "/sites/:website/shared-links", SiteController, :create_shared_link
    get "/sites/:website/shared-links/:slug/edit", SiteController, :edit_shared_link
    put "/sites/:website/shared-links/:slug", SiteController, :update_shared_link
    delete "/sites/:website/shared-links/:slug", SiteController, :delete_shared_link

    get "/sites/:website/custom-domains/new", SiteController, :new_custom_domain
    get "/sites/:website/custom-domains/dns-setup", SiteController, :custom_domain_dns_setup
    get "/sites/:website/custom-domains/snippet", SiteController, :custom_domain_snippet
    post "/sites/:website/custom-domains", SiteController, :add_custom_domain
    delete "/sites/:website/custom-domains/:id", SiteController, :delete_custom_domain

    get "/sites/:website/memberships/invite", Site.MembershipController, :invite_member_form
    post "/sites/:website/memberships/invite", Site.MembershipController, :invite_member

    post "/sites//invitations/:invitation_id/accept", InvitationController, :accept_invitation
    post "/sites//invitations/:invitation_id/reject", InvitationController, :reject_invitation
    delete "/sites//invitations/:invitation_id", InvitationController, :remove_invitation

    get "/sites/:website/transfer-ownership", Site.MembershipController, :transfer_ownership_form
    post "/sites/:website/transfer-ownership", Site.MembershipController, :transfer_ownership

    put "/sites/:website/memberships/:id/role/:new_role", Site.MembershipController, :update_role
    delete "/sites/:website/memberships/:id", Site.MembershipController, :remove_member

    get "/sites/:website/weekly-report/unsubscribe", UnsubscribeController, :weekly_report
    get "/sites/:website/monthly-report/unsubscribe", UnsubscribeController, :monthly_report

    get "/:website/snippet", SiteController, :add_snippet
    get "/:website/settings", SiteController, :settings
    get "/:website/settings/general", SiteController, :settings_general
    get "/:website/settings/people", SiteController, :settings_people
    get "/:website/settings/visibility", SiteController, :settings_visibility
    get "/:website/settings/goals", SiteController, :settings_goals
    get "/:website/settings/search-console", SiteController, :settings_search_console
    get "/:website/settings/email-reports", SiteController, :settings_email_reports
    get "/:website/settings/custom-domain", SiteController, :settings_custom_domain
    get "/:website/settings/danger-zone", SiteController, :settings_danger_zone
    get "/:website/goals/new", SiteController, :new_goal
    post "/:website/goals", SiteController, :create_goal
    delete "/:website/goals/:id", SiteController, :delete_goal
    put "/:website/settings", SiteController, :update_settings
    put "/:website/settings/google", SiteController, :update_google_auth
    delete "/:website/settings/google", SiteController, :delete_google_auth
    delete "/:website", SiteController, :delete_site
    delete "/:website/stats", SiteController, :reset_stats

    get "/:domain/visitors.csv", StatsController, :csv_export
    get "/:domain/*path", StatsController, :stats
  end
end
