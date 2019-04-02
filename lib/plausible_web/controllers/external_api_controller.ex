defmodule PlausibleWeb.ExternalApiController do
  use PlausibleWeb, :controller
  require Logger

  @blacklist_user_ids [
    "e8150466-7ddb-4771-bcf5-7c58f232e8a6"
  ]

  def page(conn, _params) do
    params = parse_body(conn)

    case create_pageview(conn, params) do
      {:ok, _pageview} ->
        conn |> send_resp(202, "")
      {:error, changeset} ->
        Sentry.capture_message("Error processing pageview", extra: %{errors: inspect(changeset.errors), params: params})
        Logger.error("Error processing pageview: #{inspect(changeset)}")
        conn |> send_resp(400, "")
    end
  end

  def error(conn, _params) do
    request = Sentry.Plug.build_request_interface_data(conn, [])
    Sentry.capture_message("JS snippet error", request: request)
    send_resp(conn, 200, "")
  end

  defp create_pageview(conn, params) do
    uri = URI.parse(params["url"])
    country_code = Plug.Conn.get_req_header(conn, "cf-ipcountry") |> List.first
    user_agent = Plug.Conn.get_req_header(conn, "user-agent") |> List.first
    if UAInspector.bot?(user_agent) || params["uid"] in @blacklist_user_ids do
      {:ok, nil}
    else
      ua = if user_agent do
        UAInspector.Parser.parse(user_agent)
      end

      ref = params["referrer"]
      ref = if ref && strip_www(URI.parse(ref).host) !== strip_www(uri.host) do
        RefInspector.parse(ref)
      end

      pageview_attrs = %{
        hostname: strip_www(uri.host),
        pathname: uri.path,
        user_agent: user_agent,
        referrer: params["referrer"],
        new_visitor: params["new_visitor"],
        screen_width: params["screen_width"],
        screen_height: params["screen_height"],
        country_code: country_code,
        screen_size: screen_string(params),
        session_id: params["sid"],
        user_id: params["uid"],
        operating_system: ua && os_name(ua),
        browser: ua && browser_name(ua),
        referrer_source: ref && referrer_source(ref)
      }

      Plausible.Pageview.changeset(%Plausible.Pageview{}, pageview_attrs)
        |> Plausible.Repo.insert
    end
  end


  defp parse_body(conn) do
    {:ok, body, _conn} = Plug.Conn.read_body(conn)
    Jason.decode!(body)
  end

  defp strip_www(nil), do: nil
  defp strip_www(hostname) do
    String.replace_prefix(hostname, "www.", "")
  end

  def screen_string(%{"screen_width" => w, "screen_height" => h}) do
    "#{w}x#{h}"
  end
  def screen_string(_), do: nil

  defp browser_name(ua) do
    case ua.client do
      %UAInspector.Result.Client{name: "Mobile Safari"} -> "Safari"
      %UAInspector.Result.Client{name: "Chrome Mobile"} -> "Chrome"
      %UAInspector.Result.Client{name: "Chrome Mobile iOS"} -> "Chrome"
      %UAInspector.Result.Client{type: "mobile app"} -> "Mobile App"
      :unknown -> "Unknown"
      client -> client.name
    end
  end

  defp os_name(ua) do
    case ua.os do
      :unknown -> "Unknown"
      os -> os.name
    end
  end

  defp referrer_source(ref) do
    case ref.source do
      :unknown -> clean_uri(ref.referer) || "Unknown"

      source -> source
    end
  end

  defp clean_uri(uri) do
    uri = URI.parse(String.trim(uri))
    if uri.scheme in ["http", "https"] do
      String.replace_leading(uri.host, "www.", "")
    else
      false
    end
  end
end
