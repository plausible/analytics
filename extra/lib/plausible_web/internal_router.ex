defmodule PlausibleWeb.InternalRouter do
  @moduledoc """
  Superadmin area router
  """

  use PlausibleWeb, :router

  import Phoenix.LiveView.Router

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
