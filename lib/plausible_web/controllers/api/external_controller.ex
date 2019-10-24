defmodule PlausibleWeb.Api.ExternalController do
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
        request = Sentry.Plug.build_request_interface_data(conn, [])
        Sentry.capture_message("Error processing pageview", extra: %{errors: inspect(changeset.errors), params: params, request: request})
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
      ref = if ref && strip_www(URI.parse(ref).host) !== strip_www(uri.host) && URI.parse(ref).host !== "localhost" do
        RefInspector.parse(ref)
      end

      pageview_attrs = %{
        hostname: strip_www(uri.host),
        pathname: uri.path,
        new_visitor: params["new_visitor"],
        country_code: country_code,
        user_id: params["uid"],
        operating_system: ua && os_name(ua),
        browser: ua && browser_name(ua),
        referrer_source: ref && referrer_source(uri, ref),
        referrer: ref && clean_referrer(params["referrer"]),
        screen_size: calculate_screen_size(params["screen_width"])
      }

      Plausible.Event.changeset(%Plausible.Event{}, pageview_attrs)
        |> Plausible.Repo.insert
    end
  end

  defp calculate_screen_size(nil) , do: nil
  defp calculate_screen_size(width) when width < 576, do: "Mobile"
  defp calculate_screen_size(width) when width < 992, do: "Tablet"
  defp calculate_screen_size(width) when width < 1440, do: "Laptop"
  defp calculate_screen_size(width) when width >= 1440, do: "Desktop"

  defp clean_referrer(referrer) do
    uri = if referrer do
      URI.parse(referrer)
    end

    if uri && uri.scheme in ["http", "https"] do
      host = String.replace_prefix(uri.host, "www.", "")
      host <> (uri.path || "")
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

  defp browser_name(ua) do
    case ua.client do
      %UAInspector.Result.Client{name: "Mobile Safari"} -> "Safari"
      %UAInspector.Result.Client{name: "Chrome Mobile"} -> "Chrome"
      %UAInspector.Result.Client{name: "Chrome Mobile iOS"} -> "Chrome"
      %UAInspector.Result.Client{type: "mobile app"} -> "Mobile App"
      :unknown -> nil
      client -> client.name
    end
  end

  defp os_name(ua) do
    case ua.os do
      :unknown -> nil
      os -> os.name
    end
  end

  defp referrer_source(uri, ref) do
    case ref.source do
      :unknown ->
        query_param_source(uri) || clean_uri(ref.referer)
      source ->
        source
    end
  end

  defp clean_uri(uri) do
    uri = URI.parse(String.trim(uri))
    if uri.scheme in ["http", "https"] do
      String.replace_leading(uri.host, "www.", "")
    end
  end

  @source_query_params ["ref", "utm_source", "source"]

  defp query_param_source(uri) do
    if uri && uri.query do
      Enum.find_value(URI.query_decoder(uri.query), fn {key, val} ->
        if Enum.member?(@source_query_params, key) do
          val
        end
      end)
    end
  end

end
