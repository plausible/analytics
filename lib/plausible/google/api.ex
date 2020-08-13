defmodule Plausible.Google.Api do
  @scope URI.encode_www_form("https://www.googleapis.com/auth/webmasters.readonly email")
  @verified_permission_levels ["siteOwner", "siteFullUser", "siteRestrictedUser"]

  def authorize_url(site_id) do
    if Application.get_env(:plausible, :environment) == "test" do
      ""
    else
      "https://accounts.google.com/o/oauth2/v2/auth?client_id=#{client_id()}&redirect_uri=#{
        redirect_uri()
      }&prompt=consent&response_type=code&access_type=offline&scope=#{@scope}&state=#{site_id}"
    end
  end

  def fetch_access_token(code) do
    res =
      HTTPoison.post!(
        "https://www.googleapis.com/oauth2/v4/token",
        "client_id=#{client_id()}&client_secret=#{client_secret()}&code=#{code}&grant_type=authorization_code&redirect_uri=#{
          redirect_uri()
        }",
        "Content-Type": "application/x-www-form-urlencoded"
      )

    Jason.decode!(res.body)
  end

  def fetch_verified_properties(auth) do
    auth = refresh_if_needed(auth)

    res =
      HTTPoison.get!("https://www.googleapis.com/webmasters/v3/sites",
        "Content-Type": "application/json",
        Authorization: "Bearer #{auth.access_token}"
      )

    Jason.decode!(res.body)
    |> Map.get("siteEntry", [])
    |> Enum.filter(fn site -> site["permissionLevel"] in @verified_permission_levels end)
    |> Enum.map(fn site -> site["siteUrl"] end)
    |> Enum.map(fn url -> String.trim_trailing(url, "/") end)
  end

  defp property_base_url(property) do
    case property do
      "sc-domain:" <> domain -> "https://" <> domain
        url -> url
    end
  end

  def fetch_stats(site, query, limit) do
    auth = refresh_if_needed(site.google_auth)
    property = URI.encode_www_form(auth.property)
    base_url = property_base_url(auth.property)
    filter_groups = if query.filters["page"] do
      [%{filters: [%{
        dimension: "page",
        expression: "https://#{base_url}#{query.filters["page"]}"
      }]}]
    end

    res =
      HTTPoison.post!(
        "https://www.googleapis.com/webmasters/v3/sites/#{property}/searchAnalytics/query",
        Jason.encode!(%{
          startDate: Date.to_iso8601(query.date_range.first),
          endDate: Date.to_iso8601(query.date_range.last),
          dimensions: ["query"],
          rowLimit: limit,
          dimensionFilterGroups: filter_groups || %{}
        }),
        "Content-Type": "application/json",
        Authorization: "Bearer #{auth.access_token}"
      )

    case res.status_code do
      200 ->
        terms =
          (Jason.decode!(res.body)["rows"] || [])
          |> Enum.filter(fn row -> row["clicks"] > 0 end)
          |> Enum.map(fn row -> %{name: row["keys"], count: round(row["clicks"])} end)

        {:ok, terms}

      401 ->
        Sentry.capture_message("Error fetching Google queries", extra: Jason.decode!(res.body))
        {:error, :invalid_credentials}

      403 ->
        Sentry.capture_message("Error fetching Google queries", extra: Jason.decode!(res.body))
        msg = Jason.decode!(res.body)["error"]["message"]
        {:error, msg}

      _ ->
        Sentry.capture_message("Error fetching Google queries", extra: Jason.decode!(res.body))
        {:error, :unknown}
    end
  end

  defp refresh_if_needed(auth) do
    if Timex.before?(auth.expires, Timex.now() |> Timex.shift(seconds: 30)) do
      refresh_token(auth)
    else
      auth
    end
  end

  defp refresh_token(auth) do
    res =
      HTTPoison.post!(
        "https://www.googleapis.com/oauth2/v4/token",
        "client_id=#{client_id()}&client_secret=#{client_secret()}&refresh_token=#{
          auth.refresh_token
        }&grant_type=refresh_token&redirect_uri=#{redirect_uri()}",
        "Content-Type": "application/x-www-form-urlencoded"
      )

    body = Jason.decode!(res.body)

    Plausible.Site.GoogleAuth.changeset(auth, %{
      access_token: body["access_token"],
      expires: NaiveDateTime.utc_now() |> NaiveDateTime.add(body["expires_in"])
    })
    |> Plausible.Repo.update!()
  end

  defp client_id() do
    Keyword.fetch!(Application.get_env(:plausible, :google), :client_id)
  end

  defp client_secret() do
    Keyword.fetch!(Application.get_env(:plausible, :google), :client_secret)
  end

  defp redirect_uri() do
    PlausibleWeb.Endpoint.clean_url() <> "/auth/google/callback"
  end
end
