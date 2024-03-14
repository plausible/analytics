defmodule PlausibleWeb.GoogleAnalytics4Controller do
  use PlausibleWeb, :controller

  plug(PlausibleWeb.RequireAccountPlug)

  plug(PlausibleWeb.AuthorizeSiteAccess, [:owner, :admin, :super_admin])

  def property_form(conn, %{
        "access_token" => access_token,
        "refresh_token" => refresh_token,
        "expires_at" => expires_at
      }) do
    redirect_route = Routes.site_path(conn, :settings_imports_exports, conn.assigns.site.domain)

    case Plausible.Google.GA4.API.list_properties(access_token) do
      {:ok, properties} ->
        conn
        |> assign(:skip_plausible_tracking, true)
        |> render("property_form.html",
          access_token: access_token,
          refresh_token: refresh_token,
          expires_at: expires_at,
          site: conn.assigns.site,
          properties: properties,
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

  def property(conn, %{
        "property" => property,
        "access_token" => access_token,
        "refresh_token" => refresh_token,
        "expires_at" => expires_at
      }) do
    site = conn.assigns.site
    start_date = Plausible.Google.GA4.API.get_analytics_start_date(access_token, property)

    case start_date do
      {:ok, nil} ->
        {:ok, properties} = Plausible.Google.GA4.API.list_properties(access_token)

        conn
        |> assign(:skip_plausible_tracking, true)
        |> render("property_form.html",
          access_token: access_token,
          refresh_token: refresh_token,
          expires_at: expires_at,
          site: site,
          properties: properties,
          selected_property_error: "No data found. Nothing to import",
          layout: {PlausibleWeb.LayoutView, "focus.html"}
        )

      {:ok, _date} ->
        redirect(conn,
          to:
            Routes.google_analytics4_path(conn, :confirm, site.domain,
              property: property,
              access_token: access_token,
              refresh_token: refresh_token,
              expires_at: expires_at
            )
        )
    end
  end

  def confirm(conn, %{
        "property" => property,
        "access_token" => access_token,
        "refresh_token" => refresh_token,
        "expires_at" => expires_at
      }) do
    site = conn.assigns.site

    start_date = Plausible.Google.GA4.API.get_analytics_start_date(access_token, property)

    end_date = Plausible.Sites.native_stats_start_date(site) || Timex.today(site.timezone)

    {:ok, {property_name, property}} =
      Plausible.Google.GA4.API.get_property(access_token, property)

    conn
    |> assign(:skip_plausible_tracking, true)
    |> render("confirm.html",
      access_token: access_token,
      refresh_token: refresh_token,
      expires_at: expires_at,
      site: site,
      selected_property: property,
      selected_property_name: property_name,
      start_date: start_date,
      end_date: end_date,
      layout: {PlausibleWeb.LayoutView, "focus.html"}
    )
  end

  def import(conn, %{
        "property" => property,
        "start_date" => start_date,
        "end_date" => end_date,
        "access_token" => access_token,
        "refresh_token" => refresh_token,
        "expires_at" => expires_at
      }) do
    site = conn.assigns.site
    current_user = conn.assigns.current_user

    redirect_route = Routes.site_path(conn, :settings_imports_exports, site.domain)

    {:ok, _} =
      Plausible.Imported.GoogleAnalytics4.new_import(
        site,
        current_user,
        property: property,
        start_date: start_date,
        end_date: end_date,
        access_token: access_token,
        refresh_token: refresh_token,
        token_expires_at: expires_at
      )

    conn
    |> put_flash(:success, "Import scheduled. An email will be sent when it completes.")
    |> redirect(external: redirect_route)
  end
end
