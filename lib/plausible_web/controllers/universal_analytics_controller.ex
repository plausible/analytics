defmodule PlausibleWeb.UniversalAnalyticsController do
  use PlausibleWeb, :controller

  plug(PlausibleWeb.RequireAccountPlug)

  plug(PlausibleWeb.AuthorizeSiteAccess, [:owner, :admin, :super_admin])

  def user_metric_notice(conn, %{
        "view_id" => view_id,
        "access_token" => access_token,
        "refresh_token" => refresh_token,
        "expires_at" => expires_at,
        "legacy" => legacy
      }) do
    site = conn.assigns.site

    conn
    |> assign(:skip_plausible_tracking, true)
    |> render("user_metric_form.html",
      site: site,
      view_id: view_id,
      access_token: access_token,
      refresh_token: refresh_token,
      expires_at: expires_at,
      legacy: legacy,
      layout: {PlausibleWeb.LayoutView, "focus.html"}
    )
  end

  def view_id_form(conn, %{
        "access_token" => access_token,
        "refresh_token" => refresh_token,
        "expires_at" => expires_at,
        "legacy" => legacy
      }) do
    redirect_route =
      if legacy == "true" do
        Routes.site_path(conn, :settings_integrations, conn.assigns.site.domain)
      else
        Routes.site_path(conn, :settings_imports_exports, conn.assigns.site.domain)
      end

    case Plausible.Google.UA.API.list_views(access_token) do
      {:ok, view_ids} ->
        conn
        |> assign(:skip_plausible_tracking, true)
        |> render("view_id_form.html",
          access_token: access_token,
          refresh_token: refresh_token,
          expires_at: expires_at,
          site: conn.assigns.site,
          view_ids: view_ids,
          legacy: legacy,
          layout: {PlausibleWeb.LayoutView, "focus.html"}
        )

      {:error, :authentication_failed} ->
        conn
        |> put_flash(
          :error,
          "We were unable to authenticate your Google Analytics account. Please check that you have granted us permission to 'See and download your Google Analytics data' and try again."
        )
        |> redirect(external: redirect_route)

      {:error, _any} ->
        conn
        |> put_flash(
          :error,
          "We were unable to list your Google Analytics properties. If the problem persists, please contact support for assistance."
        )
        |> redirect(external: redirect_route)
    end
  end

  # see https://stackoverflow.com/a/57416769
  @google_analytics_new_user_metric_date ~D[2016-08-24]
  def view_id(conn, %{
        "view_id" => view_id,
        "access_token" => access_token,
        "refresh_token" => refresh_token,
        "expires_at" => expires_at,
        "legacy" => legacy
      }) do
    site = conn.assigns.site
    start_date = Plausible.Google.UA.API.get_analytics_start_date(view_id, access_token)

    case start_date do
      {:ok, nil} ->
        {:ok, view_ids} = Plausible.Google.UA.API.list_views(access_token)

        conn
        |> assign(:skip_plausible_tracking, true)
        |> render("view_id_form.html",
          access_token: access_token,
          refresh_token: refresh_token,
          expires_at: expires_at,
          site: site,
          view_ids: view_ids,
          selected_view_id_error: "No data found. Nothing to import",
          legacy: legacy,
          layout: {PlausibleWeb.LayoutView, "focus.html"}
        )

      {:ok, date} ->
        if Timex.before?(date, @google_analytics_new_user_metric_date) do
          redirect(conn,
            to:
              Routes.universal_analytics_path(conn, :user_metric_notice, site.domain,
                view_id: view_id,
                access_token: access_token,
                refresh_token: refresh_token,
                expires_at: expires_at,
                legacy: legacy
              )
          )
        else
          redirect(conn,
            to:
              Routes.universal_analytics_path(conn, :confirm, site.domain,
                view_id: view_id,
                access_token: access_token,
                refresh_token: refresh_token,
                expires_at: expires_at,
                legacy: legacy
              )
          )
        end
    end
  end

  def confirm(conn, %{
        "view_id" => view_id,
        "access_token" => access_token,
        "refresh_token" => refresh_token,
        "expires_at" => expires_at,
        "legacy" => legacy
      }) do
    site = conn.assigns.site

    start_date = Plausible.Google.UA.API.get_analytics_start_date(view_id, access_token)

    end_date = Plausible.Sites.native_stats_start_date(site) || Timex.today(site.timezone)

    {:ok, {view_name, view_id}} = Plausible.Google.UA.API.get_view(access_token, view_id)

    conn
    |> assign(:skip_plausible_tracking, true)
    |> render("confirm.html",
      access_token: access_token,
      refresh_token: refresh_token,
      expires_at: expires_at,
      site: site,
      selected_view_id: view_id,
      selected_view_id_name: view_name,
      start_date: start_date,
      end_date: end_date,
      legacy: legacy,
      layout: {PlausibleWeb.LayoutView, "focus.html"}
    )
  end

  def import(conn, %{
        "view_id" => view_id,
        "start_date" => start_date,
        "end_date" => end_date,
        "access_token" => access_token,
        "refresh_token" => refresh_token,
        "expires_at" => expires_at,
        "legacy" => legacy
      }) do
    site = conn.assigns.site
    current_user = conn.assigns.current_user

    redirect_route =
      if legacy == "true" do
        Routes.site_path(conn, :settings_integrations, site.domain)
      else
        Routes.site_path(conn, :settings_imports_exports, site.domain)
      end

    {:ok, _} =
      Plausible.Imported.UniversalAnalytics.new_import(
        site,
        current_user,
        view_id: view_id,
        start_date: start_date,
        end_date: end_date,
        access_token: access_token,
        refresh_token: refresh_token,
        token_expires_at: expires_at,
        legacy: legacy == "true"
      )

    conn
    |> put_flash(:success, "Import scheduled. An email will be sent when it completes.")
    |> redirect(external: redirect_route)
  end
end
