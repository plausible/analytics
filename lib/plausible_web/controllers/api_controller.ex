defmodule PlausibleWeb.ApiController do
  use PlausibleWeb, :controller
  require Logger

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

  def error(conn, params) do
    Sentry.capture_message("JS snippet error", extra: %{message: params["message"]})
    send_resp(conn, 200, "")
  end

  defp create_pageview(conn, params) do
    uri = URI.parse(params["url"])
    user_agent = Plug.Conn.get_req_header(conn, "user-agent") |> List.first
    if UAInspector.bot?(user_agent) do
      {:ok, nil}
    else
      ua = if user_agent do
        UAInspector.Parser.parse(user_agent)
      end

      ref = params["referrer"]
      ref = if ref && !String.contains?(ref, strip_www(uri.host)) do
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
        screen_size: screen_string(params),
        session_id: params["sid"],
        user_id: params["uid"],
        device_type: ua && device_type(ua),
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

  defp device_type(ua) do
    case ua.device do
      :unknown -> "Unknown"
      device -> String.capitalize(device.type)
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
