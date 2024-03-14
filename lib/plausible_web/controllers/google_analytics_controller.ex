defmodule PlausibleWeb.GoogleAnalyticsController do
  use PlausibleWeb, :controller

  plug(PlausibleWeb.RequireAccountPlug)

  plug(PlausibleWeb.AuthorizeSiteAccess, [:owner, :admin, :super_admin])

  def user_metric_notice(conn, %{
        "property_or_view" => property_or_view,
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
      property_or_view: property_or_view,
      access_token: access_token,
      refresh_token: refresh_token,
      expires_at: expires_at,
      legacy: legacy,
      layout: {PlausibleWeb.LayoutView, "focus.html"}
    )
  end

  def property_or_view_form(conn, %{
        "access_token" => access_token,
        "refresh_token" => refresh_token,
        "expires_at" => expires_at,
        "legacy" => legacy
      }) do
    site = conn.assigns.site

    redirect_route =
      if legacy == "true" do
        Routes.site_path(conn, :settings_integrations, site.domain)
      else
        Routes.site_path(conn, :settings_imports_exports, site.domain)
      end

    case Plausible.Google.API.list_properties_and_views(access_token) do
      {:ok, properties_and_views} ->
        conn
        |> assign(:skip_plausible_tracking, true)
        |> render("property_or_view_form.html",
          access_token: access_token,
          refresh_token: refresh_token,
          expires_at: expires_at,
          site: conn.assigns.site,
          properties_and_views: properties_and_views,
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

  def property_or_view(conn, %{
        "property_or_view" => property_or_view,
        "access_token" => access_token,
        "refresh_token" => refresh_token,
        "expires_at" => expires_at,
        "legacy" => legacy
      }) do
    site = conn.assigns.site
    start_date = Plausible.Google.API.get_analytics_start_date(access_token, property_or_view)

    case start_date do
      {:ok, nil} ->
        {:ok, properties_and_views} = Plausible.Google.API.list_properties_and_views(access_token)

        conn
        |> assign(:skip_plausible_tracking, true)
        |> render("property_or_view_form.html",
          access_token: access_token,
          refresh_token: refresh_token,
          expires_at: expires_at,
          site: site,
          properties_and_views: properties_and_views,
          selected_property_or_view_error: "No data found. Nothing to import",
          legacy: legacy,
          layout: {PlausibleWeb.LayoutView, "focus.html"}
        )

      {:ok, date} ->
        action =
          if Timex.before?(date, @google_analytics_new_user_metric_date) do
            :user_metric_notice
          else
            :confirm
          end

        redirect(conn,
          to:
            Routes.google_analytics_path(conn, action, site.domain,
              property_or_view: property_or_view,
              access_token: access_token,
              refresh_token: refresh_token,
              expires_at: expires_at,
              legacy: legacy
            )
        )
    end
  end

  def confirm(conn, %{
        "property_or_view" => property_or_view,
        "access_token" => access_token,
        "refresh_token" => refresh_token,
        "expires_at" => expires_at,
        "legacy" => legacy
      }) do
    site = conn.assigns.site

    start_date = Plausible.Google.API.get_analytics_start_date(access_token, property_or_view)

    end_date = Plausible.Sites.native_stats_start_date(site) || Timex.today(site.timezone)

    {:ok, %{name: property_or_view_name, id: property_or_view}} =
      Plausible.Google.API.get_property_or_view(access_token, property_or_view)

    conn
    |> assign(:skip_plausible_tracking, true)
    |> render("confirm.html",
      access_token: access_token,
      refresh_token: refresh_token,
      expires_at: expires_at,
      site: site,
      selected_property_or_view: property_or_view,
      selected_property_or_view_name: property_or_view_name,
      start_date: start_date,
      end_date: end_date,
      property?: property?(property_or_view),
      legacy: legacy,
      layout: {PlausibleWeb.LayoutView, "focus.html"}
    )
  end

  def import(conn, %{
        "property_or_view" => property_or_view,
        "start_date" => start_date,
        "end_date" => end_date,
        "access_token" => access_token,
        "refresh_token" => refresh_token,
        "expires_at" => expires_at,
        "legacy" => legacy
      }) do
    site = conn.assigns.site
    current_user = conn.assigns.current_user

    redirect_route = Routes.site_path(conn, :settings_imports_exports, site.domain)

    if property?(property_or_view) do
      {:ok, _} =
        Plausible.Imported.GoogleAnalytics4.new_import(
          site,
          current_user,
          property: property_or_view,
          start_date: start_date,
          end_date: end_date,
          access_token: access_token,
          refresh_token: refresh_token,
          token_expires_at: expires_at
        )
    else
      Plausible.Imported.UniversalAnalytics.new_import(
        site,
        current_user,
        view_id: property_or_view,
        start_date: start_date,
        end_date: end_date,
        access_token: access_token,
        refresh_token: refresh_token,
        token_expires_at: expires_at,
        legacy: legacy == "true"
      )
    end

    conn
    |> put_flash(:success, "Import scheduled. An email will be sent when it completes.")
    |> redirect(external: redirect_route)
  end

  def property?(value) when is_binary(value), do: String.starts_with?(value, "properties/")
end
