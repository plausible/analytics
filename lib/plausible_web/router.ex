defmodule PlausibleWeb.Router do
  use PlausibleWeb, :router
  use Plausible
  import Phoenix.LiveView.Router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_secure_browser_headers
    plug PlausibleWeb.Plugs.NoRobots
    on_ee(do: nil, else: plug(PlausibleWeb.FirstLaunchPlug, redirect_to: "/register"))
    plug PlausibleWeb.AuthPlug
    plug PlausibleWeb.Plugs.UserSessionTouch
  end

  pipeline :shared_link do
    plug :accepts, ["html"]
    plug :put_secure_browser_headers
    plug PlausibleWeb.Plugs.NoRobots
  end

  pipeline :csrf do
    plug :protect_from_forgery
  end

  pipeline :app_layout do
    plug :put_root_layout, html: {PlausibleWeb.LayoutView, :app}
  end

  pipeline :external_api do
    plug :accepts, ["json"]
  end

  pipeline :api do
    plug :accepts, ["json"]
    plug :fetch_session
    plug PlausibleWeb.AuthPlug
  end

  pipeline :internal_stats_api do
    plug :accepts, ["json"]
    plug :fetch_session
    plug PlausibleWeb.AuthPlug
    plug PlausibleWeb.Plugs.AuthorizeSiteAccess
    plug PlausibleWeb.Plugs.NoRobots
  end

  pipeline :docs_stats_api do
    plug :accepts, ["json"]
    plug :fetch_session
    plug PlausibleWeb.AuthPlug

    plug PlausibleWeb.Plugs.AuthorizeSiteAccess,
         {[:admin, :editor, :super_admin, :owner], "site_id"}

    plug PlausibleWeb.Plugs.NoRobots
  end

  pipeline :public_api do
    plug :accepts, ["json"]
  end

  on_ee do
    pipeline :flags do
      plug :accepts, ["html"]
      plug :put_secure_browser_headers
      plug PlausibleWeb.Plugs.NoRobots
      plug :fetch_session

      plug PlausibleWeb.AuthPlug
      plug PlausibleWeb.SuperAdminOnlyPlug
    end
  end

  if Mix.env() in [:dev, :ce_dev] do
    forward "/sent-emails", Bamboo.SentEmailViewerPlug
  end

  on_ee do
    use Kaffy.Routes,
      scope: "/crm",
      pipe_through: [
        PlausibleWeb.Plugs.NoRobots,
        PlausibleWeb.AuthPlug,
        PlausibleWeb.SuperAdminOnlyPlug
      ]
  end

  on_ee do
    scope "/crm", PlausibleWeb do
      pipe_through :flags
      get "/auth/user/:user_id/usage", AdminController, :usage
      get "/billing/user/:user_id/current_plan", AdminController, :current_plan
      get "/billing/search/user-by-id/:user_id", AdminController, :user_by_id
      post "/billing/search/user", AdminController, :user_search
    end
  end

  on_ee do
    scope path: "/flags" do
      pipe_through :flags
      forward "/", FunWithFlags.UI.Router, namespace: "flags"
    end
  end

  # Routes for plug integration testing
  if Mix.env() in [:test, :ce_test] do
    scope "/plug-tests", PlausibleWeb do
      scope [] do
        pipe_through :browser

        get("/basic", TestController, :browser)
        get("/:domain/shared-link/:slug", TestController, :browser)
        get("/:domain/with-domain", TestController, :browser)
      end

      scope [] do
        pipe_through :api

        get("/api-basic", TestController, :api)
        get("/:domain/api-with-domain", TestController, :api)
      end
    end
  end

  scope path: "/api/plugins", as: :plugins_api do
    pipeline :plugins_api_auth do
      plug(PlausibleWeb.Plugs.AuthorizePluginsAPI)
    end

    pipeline :plugins_api do
      plug(:accepts, ["json"])
      plug(OpenApiSpex.Plug.PutApiSpec, module: PlausibleWeb.Plugins.API.Spec)
    end

    scope "/spec" do
      pipe_through(:plugins_api)
      get("/openapi", OpenApiSpex.Plug.RenderSpec, [])
      get("/swagger-ui", OpenApiSpex.Plug.SwaggerUI, path: "/api/plugins/spec/openapi")
    end

    scope "/v1/capabilities", PlausibleWeb.Plugins.API.Controllers, assigns: %{plugins_api: true} do
      pipe_through([:plugins_api])
      get("/", Capabilities, :index)
    end

    scope "/v1", PlausibleWeb.Plugins.API.Controllers, assigns: %{plugins_api: true} do
      pipe_through([:plugins_api, :plugins_api_auth])

      get("/shared_links", SharedLinks, :index)
      get("/shared_links/:id", SharedLinks, :get)
      put("/shared_links", SharedLinks, :create)

      get("/goals", Goals, :index)
      get("/goals/:id", Goals, :get)
      put("/goals", Goals, :create)

      on_ee do
        get("/funnels/:id", Funnels, :get)
        get("/funnels", Funnels, :index)
        put("/funnels", Funnels, :create)
      end

      delete("/goals/:id", Goals, :delete)
      delete("/goals", Goals, :delete_bulk)

      put("/custom_props", CustomProps, :enable)
      delete("/custom_props", CustomProps, :disable)
    end
  end

  scope "/api/stats", PlausibleWeb.Api do
    pipe_through :internal_stats_api

    on_ee do
      get "/:domain/funnels/:id", StatsController, :funnel
    end

    get "/:domain/current-visitors", StatsController, :current_visitors
    get "/:domain/main-graph", StatsController, :main_graph
    get "/:domain/top-stats", StatsController, :top_stats
    get "/:domain/sources", StatsController, :sources
    get "/:domain/channels", StatsController, :channels
    get "/:domain/utm_mediums", StatsController, :utm_mediums
    get "/:domain/utm_sources", StatsController, :utm_sources
    get "/:domain/utm_campaigns", StatsController, :utm_campaigns
    get "/:domain/utm_contents", StatsController, :utm_contents
    get "/:domain/utm_terms", StatsController, :utm_terms
    get "/:domain/referrers/:referrer", StatsController, :referrer_drilldown
    get "/:domain/pages", StatsController, :pages
    get "/:domain/entry-pages", StatsController, :entry_pages
    get "/:domain/exit-pages", StatsController, :exit_pages
    get "/:domain/countries", StatsController, :countries
    get "/:domain/regions", StatsController, :regions
    get "/:domain/cities", StatsController, :cities
    get "/:domain/browsers", StatsController, :browsers
    get "/:domain/browser-versions", StatsController, :browser_versions
    get "/:domain/operating-systems", StatsController, :operating_systems
    get "/:domain/operating-system-versions", StatsController, :operating_system_versions
    get "/:domain/screen-sizes", StatsController, :screen_sizes
    get "/:domain/conversions", StatsController, :conversions
    get "/:domain/custom-prop-values/:prop_key", StatsController, :custom_prop_values
    get "/:domain/suggestions/:filter_name", StatsController, :filter_suggestions

    get "/:domain/suggestions/custom-prop-values/:prop_key",
        StatsController,
        :custom_prop_value_filter_suggestions
  end

  scope "/api/v1/stats", PlausibleWeb.Api, assigns: %{api_scope: "stats:read:*"} do
    pipe_through [:public_api, PlausibleWeb.Plugs.AuthorizePublicAPI]

    get "/realtime/visitors", ExternalStatsController, :realtime_visitors
    get "/aggregate", ExternalStatsController, :aggregate
    get "/breakdown", ExternalStatsController, :breakdown
    get "/timeseries", ExternalStatsController, :timeseries
  end

  scope "/api/v2", PlausibleWeb.Api, assigns: %{api_scope: "stats:read:*", schema_type: :public} do
    pipe_through [:public_api, PlausibleWeb.Plugs.AuthorizePublicAPI]

    post "/query", ExternalQueryApiController, :query

    if Mix.env() in [:test, :ce_test] do
      scope assigns: %{schema_type: :internal} do
        post "/query-internal-test", ExternalQueryApiController, :query
      end
    end
  end

  scope "/api/docs", PlausibleWeb.Api do
    get "/query/schema.json", ExternalQueryApiController, :schema

    scope assigns: %{schema_type: :public} do
      pipe_through :docs_stats_api

      post "/query", ExternalQueryApiController, :query
    end
  end

  on_ee do
    scope "/api/v1/sites", PlausibleWeb.Api do
      pipe_through :public_api

      scope assigns: %{api_scope: "sites:read:*"} do
        pipe_through PlausibleWeb.Plugs.AuthorizePublicAPI

        get "/", ExternalSitesController, :index
        get "/goals", ExternalSitesController, :goals_index
        get "/:site_id", ExternalSitesController, :get_site
      end

      scope assigns: %{api_scope: "sites:provision:*"} do
        pipe_through PlausibleWeb.Plugs.AuthorizePublicAPI

        post "/", ExternalSitesController, :create_site
        put "/shared-links", ExternalSitesController, :find_or_create_shared_link
        put "/goals", ExternalSitesController, :find_or_create_goal
        delete "/goals/:goal_id", ExternalSitesController, :delete_goal
        put "/:site_id", ExternalSitesController, :update_site
        delete "/:site_id", ExternalSitesController, :delete_site
      end
    end
  end

  scope "/api", PlausibleWeb do
    scope [] do
      pipe_through :external_api

      post "/event", Api.ExternalController, :event
      get "/error", Api.ExternalController, :error
      get "/health", Api.ExternalController, :health
      get "/system", Api.ExternalController, :info
    end

    scope [] do
      pipe_through :api
      post "/paddle/webhook", Api.PaddleController, :webhook
      get "/paddle/currency", Api.PaddleController, :currency

      put "/:domain/disable-feature", Api.InternalController, :disable_feature

      get "/sites", Api.InternalController, :sites
    end
  end

  scope "/", PlausibleWeb do
    pipe_through [:browser, :csrf]

    scope alias: Live, assigns: %{connect_live_socket: true} do
      pipe_through [PlausibleWeb.RequireLoggedOutPlug, :app_layout]

      scope assigns: %{disable_registration_for: [:invite_only, true]} do
        pipe_through PlausibleWeb.Plugs.MaybeDisableRegistration

        live "/register", RegisterForm, :register_form, as: :auth
      end

      scope assigns: %{
              disable_registration_for: true,
              dogfood_page_path: "/register/invitation/:invitation_id"
            } do
        pipe_through PlausibleWeb.Plugs.MaybeDisableRegistration

        live "/register/invitation/:invitation_id", RegisterForm, :register_from_invitation_form,
          as: :auth
      end
    end

    get "/activate", AuthController, :activate_form
    post "/activate/request-code", AuthController, :request_activation_code
    post "/activate", AuthController, :activate
    get "/login", AuthController, :login_form
    post "/login", AuthController, :login
    get "/password/request-reset", AuthController, :password_reset_request_form
    post "/password/request-reset", AuthController, :password_reset_request
    post "/2fa/setup/initiate", AuthController, :initiate_2fa_setup
    get "/2fa/setup/verify", AuthController, :verify_2fa_setup_form
    post "/2fa/setup/verify", AuthController, :verify_2fa_setup
    post "/2fa/disable", AuthController, :disable_2fa
    post "/2fa/recovery_codes", AuthController, :generate_2fa_recovery_codes
    get "/2fa/verify", AuthController, :verify_2fa_form
    post "/2fa/verify", AuthController, :verify_2fa
    get "/2fa/use_recovery_code", AuthController, :verify_2fa_recovery_code_form
    post "/2fa/use_recovery_code", AuthController, :verify_2fa_recovery_code
    get "/password/reset", AuthController, :password_reset_form
    post "/password/reset", AuthController, :password_reset
    get "/avatar/:hash", AvatarController, :avatar
    post "/error_report", ErrorReportController, :submit_error_report
  end

  scope "/", PlausibleWeb do
    pipe_through [:shared_link]

    get "/share/:domain", StatsController, :shared_link
    post "/share/:slug/authenticate", StatsController, :authenticate_shared_link
  end

  scope "/settings", PlausibleWeb do
    pipe_through [:browser, :csrf, PlausibleWeb.RequireAccountPlug]

    get "/", SettingsController, :index
    get "/preferences", SettingsController, :preferences

    post "/preferences/name", SettingsController, :update_name
    post "/preferences/theme", SettingsController, :update_theme

    get "/security", SettingsController, :security
    delete "/security/user-sessions/:id", SettingsController, :delete_session

    post "/security/email/cancel", SettingsController, :cancel_update_email
    post "/security/email", SettingsController, :update_email
    post "/security/password", SettingsController, :update_password

    get "/billing/subscription", SettingsController, :subscription
    get "/billing/invoices", SettingsController, :invoices
    get "/api-keys", SettingsController, :api_keys

    get "/api-keys/new", SettingsController, :new_api_key
    post "/api-keys", SettingsController, :create_api_key
    delete "/api-keys/:id", SettingsController, :delete_api_key

    get "/danger-zone", SettingsController, :danger_zone

    on_ee do
      get "/team/general", SettingsController, :team_general
      post "/team/general/name", SettingsController, :update_team_name
    end
  end

  scope "/", PlausibleWeb do
    pipe_through [:browser, :csrf]

    get "/logout", AuthController, :logout
    delete "/me", AuthController, :delete_me

    get "/auth/google/callback", AuthController, :google_auth_callback

    on_ee do
      get "/helpscout/callback", HelpScoutController, :callback
      get "/helpscout/show", HelpScoutController, :show
      get "/helpscout/search", HelpScoutController, :search
    end

    get "/", PageController, :index

    get "/billing/change-plan/preview/:plan_id", BillingController, :change_plan_preview
    post "/billing/change-plan/:new_plan_id", BillingController, :change_plan
    get "/billing/choose-plan", BillingController, :choose_plan
    get "/billing/upgrade-to-enterprise-plan", BillingController, :upgrade_to_enterprise_plan
    get "/billing/upgrade-success", BillingController, :upgrade_success
    get "/billing/subscription/ping", BillingController, :ping_subscription

    scope alias: Live, assigns: %{connect_live_socket: true} do
      pipe_through [:app_layout, PlausibleWeb.RequireAccountPlug]

      live "/sites", Sites, :index, as: :site
    end

    get "/sites/new", SiteController, :new
    post "/sites", SiteController, :create_site
    get "/sites/:domain/change-domain", SiteController, :change_domain
    put "/sites/:domain/change-domain", SiteController, :change_domain_submit
    post "/sites/:domain/make-public", SiteController, :make_public
    post "/sites/:domain/make-private", SiteController, :make_private
    post "/sites/:domain/weekly-report/enable", SiteController, :enable_weekly_report
    post "/sites/:domain/weekly-report/disable", SiteController, :disable_weekly_report
    post "/sites/:domain/weekly-report/recipients", SiteController, :add_weekly_report_recipient

    delete "/sites/:domain/weekly-report/recipients/:recipient",
           SiteController,
           :remove_weekly_report_recipient

    post "/sites/:domain/monthly-report/enable", SiteController, :enable_monthly_report
    post "/sites/:domain/monthly-report/disable", SiteController, :disable_monthly_report

    post "/sites/:domain/monthly-report/recipients",
         SiteController,
         :add_monthly_report_recipient

    delete "/sites/:domain/monthly-report/recipients/:recipient",
           SiteController,
           :remove_monthly_report_recipient

    post "/sites/:domain/traffic-change-notification/:type/enable",
         SiteController,
         :enable_traffic_change_notification

    post "/sites/:domain/traffic-change-notification/:type/disable",
         SiteController,
         :disable_traffic_change_notification

    put "/sites/:domain/traffic-change-notification/:type",
        SiteController,
        :update_traffic_change_notification

    post "/sites/:domain/traffic-change-notification/:type/recipients",
         SiteController,
         :add_traffic_change_notification_recipient

    delete "/sites/:domain/traffic-change-notification/:type/recipients/:recipient",
           SiteController,
           :remove_traffic_change_notification_recipient

    get "/sites/:domain/shared-links/new", SiteController, :new_shared_link
    post "/sites/:domain/shared-links", SiteController, :create_shared_link
    get "/sites/:domain/shared-links/:slug/edit", SiteController, :edit_shared_link
    put "/sites/:domain/shared-links/:slug", SiteController, :update_shared_link
    delete "/sites/:domain/shared-links/:slug", SiteController, :delete_shared_link

    get "/sites/:domain/memberships/invite", Site.MembershipController, :invite_member_form
    post "/sites/:domain/memberships/invite", Site.MembershipController, :invite_member

    post "/sites/invitations/:invitation_id/accept", InvitationController, :accept_invitation

    post "/sites/invitations/:invitation_id/reject", InvitationController, :reject_invitation

    delete "/sites/:domain/invitations/:invitation_id", InvitationController, :remove_invitation

    get "/sites/:domain/transfer-ownership", Site.MembershipController, :transfer_ownership_form
    post "/sites/:domain/transfer-ownership", Site.MembershipController, :transfer_ownership

    put "/sites/:domain/memberships/u/:id/role/:new_role",
        Site.MembershipController,
        :update_role_by_user

    delete "/sites/:domain/memberships/u/:id", Site.MembershipController, :remove_member_by_user

    get "/sites/:domain/weekly-report/unsubscribe", UnsubscribeController, :weekly_report
    get "/sites/:domain/monthly-report/unsubscribe", UnsubscribeController, :monthly_report

    scope alias: Live, assigns: %{connect_live_socket: true} do
      pipe_through [:app_layout, PlausibleWeb.RequireAccountPlug]

      scope assigns: %{
              dogfood_page_path: "/:website/installation"
            } do
        live "/:domain/installation", Installation, :installation, as: :site
      end

      scope assigns: %{
              dogfood_page_path: "/:website/verification"
            } do
        live "/:domain/verification", Verification, :verification, as: :site
      end
    end

    get "/:domain/settings", SiteController, :settings
    get "/:domain/settings/general", SiteController, :settings_general
    get "/:domain/settings/people", SiteController, :settings_people
    get "/:domain/settings/visibility", SiteController, :settings_visibility
    get "/:domain/settings/goals", SiteController, :settings_goals
    get "/:domain/settings/properties", SiteController, :settings_props

    on_ee do
      get "/:domain/settings/funnels", SiteController, :settings_funnels
    end

    get "/:domain/settings/email-reports", SiteController, :settings_email_reports
    get "/:domain/settings/danger-zone", SiteController, :settings_danger_zone
    get "/:domain/settings/integrations", SiteController, :settings_integrations
    get "/:domain/settings/shields/:shield", SiteController, :settings_shields
    get "/:domain/settings/imports-exports", SiteController, :settings_imports_exports

    put "/:domain/settings/features/visibility/:setting",
        SiteController,
        :update_feature_visibility

    put "/:domain/settings", SiteController, :update_settings
    put "/:domain/settings/google", SiteController, :update_google_auth
    delete "/:domain/settings/google-search", SiteController, :delete_google_auth
    delete "/:domain/settings/google-import", SiteController, :delete_google_auth
    delete "/:domain", SiteController, :delete_site
    delete "/:domain/stats", SiteController, :reset_stats

    get "/:domain/import/google-analytics/property",
        GoogleAnalyticsController,
        :property_form

    post "/:domain/import/google-analytics/property",
         GoogleAnalyticsController,
         :property

    get "/:domain/import/google-analytics/confirm", GoogleAnalyticsController, :confirm
    post "/:domain/settings/google-import", GoogleAnalyticsController, :import

    delete "/:domain/settings/forget-imported", SiteController, :forget_imported
    delete "/:domain/settings/forget-import/:import_id", SiteController, :forget_import

    get "/:domain/download/export", SiteController, :download_export
    get "/:domain/settings/import", SiteController, :csv_import

    get "/debug/clickhouse", DebugController, :clickhouse

    get "/:domain/export", StatsController, :csv_export
    get "/:domain/*path", StatsController, :stats
  end
end
