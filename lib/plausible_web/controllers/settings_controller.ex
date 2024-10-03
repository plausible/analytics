defmodule PlausibleWeb.SettingsController do
  use PlausibleWeb, :controller
  use Plausible.Repo

  require Logger

  def index(conn, _params) do
    redirect(conn, to: Routes.settings_path(conn, :preferences))
  end

  def preferences(conn, _params) do
    render(conn, :preferences, layout: {PlausibleWeb.LayoutView, :settings})
  end

  def security(conn, _params) do
    render(conn, :security, layout: {PlausibleWeb.LayoutView, :settings})
  end

  def subscription(conn, _params) do
    render(conn, :subscription, layout: {PlausibleWeb.LayoutView, :settings})
  end

  def invoices(conn, _params) do
    render(conn, :invoices, layout: {PlausibleWeb.LayoutView, :settings})
  end

  def api_keys(conn, _params) do
    render(conn, :api_keys, layout: {PlausibleWeb.LayoutView, :settings})
  end

  def danger_zone(conn, _params) do
    render(conn, :danger_zone, layout: {PlausibleWeb.LayoutView, :settings})
  end
end
