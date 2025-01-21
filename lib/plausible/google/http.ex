defmodule Plausible.Google.HTTP do
  require Logger
  alias Plausible.HTTPClient

  def list_sites(access_token) do
    url = "#{api_url()}/webmasters/v3/sites"
    headers = [{"Content-Type", "application/json"}, {"Authorization", "Bearer #{access_token}"}]

    case HTTPClient.impl().get(url, headers) do
      {:ok, %{body: body}} ->
        {:ok, body}

      {:error, %{reason: %{status: s}}} when s in [401, 403] ->
        {:error, "google_auth_error"}

      {:error, %{reason: %{body: %{"error" => error}}}} ->
        {:error, error}

      {:error, reason} ->
        Logger.error("Google Analytics: failed to list sites: #{inspect(reason)}")
        {:error, "failed_to_list_sites"}
    end
  end

  def fetch_access_token!(code) do
    url = "#{api_url()}/oauth2/v4/token"
    headers = [{"Content-Type", "application/x-www-form-urlencoded"}]

    params = %{
      client_id: client_id(),
      client_secret: client_secret(),
      code: code,
      grant_type: :authorization_code,
      redirect_uri: redirect_uri()
    }

    {:ok, response} = HTTPClient.post(url, headers, params)

    response.body
  end

  def list_stats(access_token, property, date_range, pagination, search_console_filters) do
    {limit, page} = pagination

    params = %{
      startDate: Date.to_iso8601(date_range.first),
      endDate: Date.to_iso8601(date_range.last),
      dimensions: ["query"],
      rowLimit: limit,
      startRow: page * limit,
      dimensionFilterGroups: search_console_filters
    }

    url =
      "#{api_url()}/webmasters/v3/sites/#{URI.encode_www_form(property)}/searchAnalytics/query"

    headers = [{"Authorization", "Bearer #{access_token}"}]

    case HTTPClient.impl().post(url, headers, params) do
      {:ok, %Finch.Response{body: body, status: 200}} ->
        {:ok, body}

      {:error, %{reason: %Finch.Response{body: _body, status: status}}}
      when status in [401, 403] ->
        {:error, "google_auth_error"}

      {:error, %{reason: %{body: %{"error" => error}}}} ->
        {:error, error}

      {:error, reason} ->
        Logger.error("Google Search Console: failed to list stats: #{inspect(reason)}")
        {:error, "failed_to_list_stats"}
    end
  end

  def refresh_auth_token(refresh_token) do
    url = "#{api_url()}/oauth2/v4/token"
    headers = [{"content-type", "application/x-www-form-urlencoded"}]

    params = %{
      client_id: client_id(),
      client_secret: client_secret(),
      refresh_token: refresh_token,
      grant_type: :refresh_token,
      redirect_uri: redirect_uri()
    }

    case HTTPClient.impl().post(url, headers, params) do
      {:ok, %Finch.Response{body: body, status: 200}} ->
        {:ok, body}

      {:error, %{reason: %Finch.Response{body: %{"error" => error}, status: _non_http_200}}} ->
        {:error, error}

      {:error, %{reason: _} = e} ->
        Logger.error("Error fetching Google queries",
          sentry: %{extra: %{error: inspect(e)}}
        )

        {:error, :unknown_error}
    end
  end

  defp config, do: Application.get_env(:plausible, :google)
  defp client_id, do: Keyword.fetch!(config(), :client_id)
  defp client_secret, do: Keyword.fetch!(config(), :client_secret)
  defp api_url, do: Keyword.fetch!(config(), :api_url)
  defp redirect_uri, do: PlausibleWeb.Endpoint.url() <> "/auth/google/callback"
end
