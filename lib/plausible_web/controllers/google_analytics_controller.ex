defmodule PlausibleWeb.GoogleAnalyticsController do
  use PlausibleWeb, :controller

  alias Plausible.Google
  alias Plausible.Imported
  use Plausible

  require Plausible.Imported.SiteImport

  plug(PlausibleWeb.RequireAccountPlug)

  plug(PlausibleWeb.Plugs.AuthorizeSiteAccess, [:owner, :editor, :admin, :super_admin])

  def property_form(
        conn,
        %{
          "access_token" => access_token,
          "refresh_token" => refresh_token,
          "expires_at" => expires_at
        } = params
      ) do
    site = conn.assigns.site

    redirect_route = Routes.site_path(conn, :settings_imports_exports, site.domain)

    result = Google.API.list_properties(access_token)

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
      {:ok, properties} ->
        conn
        |> assign(:skip_plausible_tracking, true)
        |> render("property_form.html",
          access_token: access_token,
          refresh_token: refresh_token,
          expires_at: expires_at,
          site: conn.assigns.site,
          properties: properties,
          selected_property_error: error
        )

      {:error, :rate_limit_exceeded} ->
        conn
        |> put_flash(
          :error,
          "Google Analytics rate limit has been exceeded. Please try again later."
        )
        |> redirect(external: redirect_route)

      {:error, {:authentication_failed, message}} ->
        default_message =
          "We were unable to authenticate your Google Analytics account. Please check that you have granted us permission to 'See and download your Google Analytics data' and try again."

        message =
          if ce?() do
            message || default_message
          else
            default_message
          end

        conn
        |> put_flash(:ttl, :timer.seconds(5))
        |> put_flash(:error, message)
        |> redirect(external: redirect_route)

      {:error, :timeout} ->
        conn
        |> put_flash(
          :error,
          "Google Analytics API has timed out. Please try again."
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

  def property(
        conn,
        %{
          "property" => property,
          "access_token" => access_token,
          "refresh_token" => refresh_token,
          "expires_at" => expires_at
        } = params
      ) do
    site = conn.assigns.site

    redirect_route = Routes.site_path(conn, :settings_imports_exports, site.domain)

    with {:ok, api_start_date} <- Google.API.get_analytics_start_date(access_token, property),
         {:ok, api_end_date} <- Google.API.get_analytics_end_date(access_token, property),
         :ok <- ensure_dates(api_start_date, api_end_date),
         {:ok, start_date, end_date} <- Imported.clamp_dates(site, api_start_date, api_end_date) do
      redirect(conn,
        external:
          Routes.google_analytics_path(conn, :confirm, site.domain,
            property: property,
            access_token: access_token,
            refresh_token: refresh_token,
            expires_at: expires_at,
            start_date: Date.to_iso8601(start_date),
            end_date: Date.to_iso8601(end_date)
          )
      )
    else
      {:error, error} when error in [:no_data, :no_time_window] ->
        params =
          params
          |> Map.take(["access_token", "refresh_token", "expires_at"])
          |> Map.put("error", Atom.to_string(error))

        property_form(conn, params)

      {:error, :rate_limit_exceeded} ->
        conn
        |> put_flash(
          :error,
          "Google Analytics rate limit has been exceeded. Please try again later."
        )
        |> redirect(external: redirect_route)

      {:error, {:authentication_failed, message}} ->
        default_message =
          "Google Analytics authentication seems to have expired. Please try again."

        message =
          if Plausible.ce?() do
            message || default_message
          else
            default_message
          end

        conn
        |> put_flash(:ttl, :timer.seconds(5))
        |> put_flash(:error, message)
        |> redirect(external: redirect_route)

      {:error, :timeout} ->
        conn
        |> put_flash(
          :error,
          "Google Analytics API has timed out. Please try again."
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
        "property" => property,
        "access_token" => access_token,
        "refresh_token" => refresh_token,
        "expires_at" => expires_at,
        "start_date" => start_date,
        "end_date" => end_date
      }) do
    site = conn.assigns.site

    start_date = Date.from_iso8601!(start_date)
    end_date = Date.from_iso8601!(end_date)

    redirect_route = Routes.site_path(conn, :settings_imports_exports, site.domain)

    case Google.API.get_property(access_token, property) do
      {:ok, %{name: property_name, id: property}} ->
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
          end_date: end_date
        )

      {:error, :rate_limit_exceeded} ->
        conn
        |> put_flash(
          :error,
          "Google Analytics rate limit has been exceeded. Please try again later."
        )
        |> redirect(external: redirect_route)

      {:error, {:authentication_failed, message}} ->
        default_message =
          "Google Analytics authentication seems to have expired. Please try again."

        message =
          if Plausible.ce?() do
            message || default_message
          else
            default_message
          end

        conn
        |> put_flash(:ttl, :timer.seconds(5))
        |> put_flash(:error, message)
        |> redirect(external: redirect_route)

      {:error, :timeout} ->
        conn
        |> put_flash(
          :error,
          "Google Analytics API has timed out. Please try again."
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
        "property" => property,
        "start_date" => start_date,
        "end_date" => end_date,
        "access_token" => access_token,
        "refresh_token" => refresh_token,
        "expires_at" => expires_at
      }) do
    site = conn.assigns.site
    current_user = conn.assigns.current_user

    start_date = Date.from_iso8601!(start_date)
    end_date = Date.from_iso8601!(end_date)

    redirect_route = Routes.site_path(conn, :settings_imports_exports, site.domain)

    import_opts = [
      label: property,
      property: property,
      start_date: start_date,
      end_date: end_date,
      access_token: access_token,
      refresh_token: refresh_token,
      token_expires_at: expires_at
    ]

    with {:ok, start_date, end_date} <- Imported.clamp_dates(site, start_date, end_date),
         import_opts = [{:start_date, start_date}, {:end_date, end_date} | import_opts],
         {:ok, _} <- Imported.GoogleAnalytics4.new_import(site, current_user, import_opts) do
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

  defp ensure_dates(%Date{}, %Date{}), do: :ok
  defp ensure_dates(_, _), do: {:error, :no_data}
end
