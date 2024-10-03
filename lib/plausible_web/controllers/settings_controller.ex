defmodule PlausibleWeb.SettingsController do
  use PlausibleWeb, :controller
  use Plausible.Repo

  alias Plausible.Auth

  require Logger

  def index(conn, _params) do
    redirect(conn, to: Routes.settings_path(conn, :preferences))
  end

  def preferences(conn, _params) do
    render_preferences(conn)
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

  def update_name(conn, %{"user" => params}) do
    changeset = Auth.User.name_changeset(conn.assigns.current_user, params)

    case Repo.update(changeset) do
      {:ok, _user} ->
        conn
        |> put_flash(:success, "Name changed")
        |> redirect(to: Routes.settings_path(conn, :preferences))

      {:error, changeset} ->
        render_preferences(conn, name_changeset: changeset)
    end
  end

  def update_theme(conn, %{"user" => params}) do
    changeset = Auth.User.theme_changeset(conn.assigns.current_user, params)

    case Repo.update(changeset) do
      {:ok, _user} ->
        conn
        |> put_flash(:success, "Theme changed")
        |> redirect(to: Routes.settings_path(conn, :preferences))

      {:error, changeset} ->
        render_preferences(conn, theme_changeset: changeset)
    end
  end

  defp render_preferences(conn, opts \\ []) do
    render(conn, :preferences,
      name_changeset:
        Keyword.get(opts, :name_changeset, Auth.User.name_changeset(conn.assigns.current_user)),
      theme_changeset:
        Keyword.get(opts, :theme_changeset, Auth.User.theme_changeset(conn.assigns.current_user)),
      layout: {PlausibleWeb.LayoutView, :settings}
    )
  end
end
