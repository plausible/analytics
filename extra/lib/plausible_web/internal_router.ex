defmodule PlausibleWeb.InternalRouter do
  @moduledoc """
  Superadmin area router
  """

  use PlausibleWeb, :router

  import Phoenix.LiveView.Router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_secure_browser_headers
    plug PlausibleWeb.Plugs.NoRobots
    plug PlausibleWeb.AuthPlug
    plug PlausibleWeb.Plugs.UserSessionTouch
  end

  pipeline :csrf do
    plug :protect_from_forgery
  end

  pipeline :superadmin_area do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_secure_browser_headers
    plug :protect_from_forgery
    plug :put_root_layout, html: {PlausibleWeb.LayoutView, :app}
    plug PlausibleWeb.AuthPlug
    plug PlausibleWeb.Plugs.UserSessionTouch
    plug PlausibleWeb.Plugs.NoRobots
    plug PlausibleWeb.SuperAdminOnlyPlug
  end

  scope "/", PlausibleWeb do
    pipe_through [:browser, :csrf]

    get "/", CustomerSupportController, :redirect_to_root
    get "/sites", CustomerSupportController, :redirect_to_root
    get "/login", AuthController, :login_form
    post "/login", AuthController, :login
    get "/logout", AuthController, :logout
    get "/password/request-reset", AuthController, :password_reset_request_form
    post "/password/request-reset", AuthController, :password_reset_request
    get "/2fa/verify", AuthController, :verify_2fa_form
    post "/2fa/verify", AuthController, :verify_2fa
    get "/2fa/use_recovery_code", AuthController, :verify_2fa_recovery_code_form
    post "/2fa/use_recovery_code", AuthController, :verify_2fa_recovery_code
    get "/password/reset", AuthController, :password_reset_form
    post "/password/reset", AuthController, :password_reset
  end

  scope path: "/flags" do
    pipe_through :superadmin_area
    forward "/", FunWithFlags.UI.Router, namespace: "flags"
  end

  scope alias: PlausibleWeb.Live,
        assigns: %{connect_live_socket: true, skip_plausible_tracking: true} do
    pipe_through :superadmin_area

    live "/cs", CustomerSupport, :index, as: :customer_support
    live "/cs/:any/:resource/:id", CustomerSupport, :details, as: :customer_support_resource
  end
end
