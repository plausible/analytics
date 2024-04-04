defmodule PlausibleWeb.GoogleAnalyticsController do
  use PlausibleWeb, :controller

  alias Plausible.Google
  alias Plausible.Imported

  require Plausible.Imported.SiteImport

  plug(PlausibleWeb.RequireAccountPlug)

  plug(PlausibleWeb.AuthorizeSiteAccess, [:owner, :admin, :super_admin])

  def user_metric_notice(conn, %{
        "property_or_view" => property_or_view,
        "access_token" => access_token,
        "refresh_token" => refresh_token,
        "expires_at" => expires_at,
        "start_date" => start_date,
        "end_date" => end_date,
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
      start_date: start_date,
      end_date: end_date,
      legacy: legacy,
      layout: {PlausibleWeb.LayoutView, "focus.html"}
    )
  end

  def property_or_view_form(
        conn,
        %{
          "access_token" => access_token,
          "refresh_token" => refresh_token,
          "expires_at" => expires_at,
          "legacy" => legacy
        } = params
      ) do
    site = conn.assigns.site

    redirect_route =
      if legacy == "true" do
        Routes.site_path(conn, :settings_integrations, site.domain)
      else
        Routes.site_path(conn, :settings_imports_exports, site.domain)
      end

    result =
      if legacy == "true" do
        Google.UA.API.list_views(access_token)
      else
        Google.API.list_properties_and_views(access_token)
      end

    error =
      case params["error"] do
        "no_data" ->
          "No data found. Nothing to import."

        "no_time_window" ->
          "Imported data time range is completely overlapping with existing data. Nothing to import."

        _ ->
          nil
      end

    case result do
      {:ok, properties_and_views} ->
        conn
        |> assign(:skip_plausible_tracking, true)
        |> render("property_or_view_form.html",
          access_token: access_token,
          refresh_token: refresh_token,
          expires_at: expires_at,
          site: conn.assigns.site,
          properties_and_views: properties_and_views,
          selected_property_or_view_error: error,
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
          "We were unable to list your Google Analytics properties and views. If the problem persists, please contact support for assistance."
        )
        |> redirect(external: redirect_route)
    end
  end

  # see https://stackoverflow.com/a/57416769
  @universal_analytics_new_user_metric_date ~D[2016-08-24]

  def property_or_view(
        conn,
        %{
          "property_or_view" => property_or_view,
          "access_token" => access_token,
          "refresh_token" => refresh_token,
          "expires_at" => expires_at,
          "legacy" => legacy
        } = params
      ) do
    site = conn.assigns.site

    redirect_route =
      if legacy == "true" do
        Routes.site_path(conn, :settings_integrations, site.domain)
      else
        Routes.site_path(conn, :settings_imports_exports, site.domain)
      end

    with {:ok, api_start_date} <-
           Google.API.get_analytics_start_date(access_token, property_or_view),
         {:ok, api_end_date} <- Google.API.get_analytics_end_date(access_token, property_or_view),
         {:ok, start_date, end_date} <- Imported.check_dates(site, api_start_date, api_end_date) do
      action =
        if Timex.before?(api_start_date, @universal_analytics_new_user_metric_date) do
          :user_metric_notice
        else
          :confirm
        end

      redirect(conn,
        external:
          Routes.google_analytics_path(conn, action, site.domain,
            property_or_view: property_or_view,
            access_token: access_token,
            refresh_token: refresh_token,
            expires_at: expires_at,
            start_date: Date.to_iso8601(start_date),
            end_date: Date.to_iso8601(end_date),
            legacy: legacy
          )
      )
    else
      {:error, error} when error in [:no_data, :no_time_window] ->
        params =
          params
          |> Map.take(["access_token", "refresh_token", "expires_at", "legacy"])
          |> Map.put("error", Atom.to_string(error))

        property_or_view_form(conn, params)

      {:error, :authentication_failed} ->
        conn
        |> put_flash(
          :error,
          "Google Analytics authentication seems to have expired. Please try again."
        )
        |> redirect(external: redirect_route)

      {:error, _any} ->
        conn
        |> put_flash(
          :error,
          "We were unable to retrieve information from Google Analytics. If the problem persists, please contact support for assistance."
        )
        |> redirect(external: redirect_route)
    end
  end

  def confirm(conn, %{
        "property_or_view" => property_or_view,
        "access_token" => access_token,
        "refresh_token" => refresh_token,
        "expires_at" => expires_at,
        "start_date" => start_date,
        "end_date" => end_date,
        "legacy" => legacy
      }) do
    site = conn.assigns.site

    start_date = Date.from_iso8601!(start_date)
    end_date = Date.from_iso8601!(end_date)

    redirect_route =
      if legacy == "true" do
        Routes.site_path(conn, :settings_integrations, site.domain)
      else
        Routes.site_path(conn, :settings_imports_exports, site.domain)
      end

    case Google.API.get_property_or_view(access_token, property_or_view) do
      {:ok, %{name: property_or_view_name, id: property_or_view}} ->
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
          property?: Google.API.property?(property_or_view),
          legacy: legacy,
          layout: {PlausibleWeb.LayoutView, "focus.html"}
        )

      {:error, :authentication_failed} ->
        conn
        |> put_flash(
          :error,
          "Google Analytics authentication seems to have expired. Please try again."
        )
        |> redirect(external: redirect_route)

      {:error, :not_found} ->
        conn
        |> put_flash(
          :error,
          "Google Analytics property not found. Please try again."
        )
        |> redirect(external: redirect_route)

      {:error, _any} ->
        conn
        |> put_flash(
          :error,
          "We were unable to retrieve information from Google Analytics. If the problem persists, please contact support for assistance."
        )
        |> redirect(external: redirect_route)
    end
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

    start_date = Date.from_iso8601!(start_date)
    end_date = Date.from_iso8601!(end_date)

    redirect_route =
      if legacy == "true" do
        Routes.site_path(conn, :settings_integrations, site.domain)
      else
        Routes.site_path(conn, :settings_imports_exports, site.domain)
      end

    import_opts = [
      label: property_or_view,
      start_date: start_date,
      end_date: end_date,
      access_token: access_token,
      refresh_token: refresh_token,
      token_expires_at: expires_at,
      legacy: legacy == "true"
    ]

    with {:ok, start_date, end_date} <- Imported.check_dates(site, start_date, end_date),
         import_opts = [{:start_date, start_date}, {:end_date, end_date} | import_opts],
         {:ok, _} <- schedule_job(site, current_user, property_or_view, import_opts) do
      conn
      |> put_flash(:success, "Import scheduled. An email will be sent when it completes.")
      |> redirect(external: redirect_route)
    else
      {:error, :no_time_window} ->
        conn
        |> put_flash(
          :error,
          "Import failed. No data could be imported because date range overlaps with existing data."
        )
        |> redirect(external: redirect_route)

      {:error, :import_in_progress} ->
        conn
        |> put_flash(
          :error,
          "There's another import still in progress. Please wait until it's completed or cancel it before starting a new one."
        )
        |> redirect(external: redirect_route)
    end
  end

  defp schedule_job(site, current_user, property_or_view, opts) do
    if Google.API.property?(property_or_view) do
      opts = Keyword.put(opts, :property, property_or_view)
      Imported.GoogleAnalytics4.new_import(site, current_user, opts)
    else
      opts = Keyword.put(opts, :view_id, property_or_view)
      Imported.UniversalAnalytics.new_import(site, current_user, opts)
    end
  end
end
