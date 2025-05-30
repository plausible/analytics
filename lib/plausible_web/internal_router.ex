defmodule PlausibleWeb.InternalRouter do
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

  pipeline :app_layout do
    plug :put_root_layout, html: {PlausibleWeb.LayoutView, :app}
  end

  pipeline :flags do
    plug :accepts, ["html"]
    plug :put_secure_browser_headers
    plug PlausibleWeb.Plugs.NoRobots
    plug :fetch_session

    plug PlausibleWeb.AuthPlug
    plug PlausibleWeb.SuperAdminOnlyPlug
  end

  scope path: "/flags" do
    pipe_through :flags
    forward "/", FunWithFlags.UI.Router, namespace: "flags"
  end

  scope alias: PlausibleWeb.Live, assigns: %{connect_live_socket: true} do
    pipe_through [:browser, :csrf, :app_layout, :flags]

    live "/cs", CustomerSupport, :index, as: :customer_support

    live "/cs/:any/:resource/:id", CustomerSupport, :details, as: :customer_support_resource
  end
end
