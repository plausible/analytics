defmodule PlausibleWeb.Api.ExternalController do
  use PlausibleWeb, :controller
  require Logger

  def event(conn, _params) do
    params = parse_body(conn)
    Sentry.Context.set_extra_context(%{request: params})

    case create_event(conn, params) do
      {:ok, _} ->
        conn |> send_resp(202, "")

      {:error, changeset} ->
        request = Sentry.Plug.build_request_interface_data(conn, [])

        Sentry.capture_message("Error processing event",
          extra: %{errors: inspect(changeset.errors), params: params, request: request}
        )

        Logger.info("Error processing event: #{inspect(changeset)}")
        conn |> send_resp(400, "")
    end
  end

  def error(conn, _params) do
    request = Sentry.Plug.build_request_interface_data(conn, [])
    Sentry.capture_message("JS snippet error", request: request)
    send_resp(conn, 200, "")
  end

  defp create_event(conn, params) do
    uri = params["url"] && URI.parse(params["url"])
    user_agent = Plug.Conn.get_req_header(conn, "user-agent") |> List.first()

    if UAInspector.bot?(user_agent) do
      {:ok, nil}
    else
      ua =
        if user_agent do
          UAInspector.Parser.parse(user_agent)
        end

      ref = parse_referrer(uri, params["referrer"])
      country_code = visitor_country(conn)
      salts = Plausible.Session.Salts.fetch()

      event_attrs = %{
        timestamp: NaiveDateTime.utc_now(),
        name: params["name"],
        hostname: strip_www(uri && uri.host),
        domain: strip_www(params["domain"]) || strip_www(uri && uri.host),
        pathname: uri && (uri.path || "/"),
        user_id: generate_user_id(conn, params, salts[:current]),
        country_code: country_code,
        operating_system: ua && os_name(ua),
        browser: ua && browser_name(ua),
        referrer_source: params["source"] || referrer_source(ref),
        referrer: clean_referrer(ref),
        screen_size: calculate_screen_size(params["screen_width"])
      }

      changeset = Plausible.ClickhouseEvent.changeset(%Plausible.ClickhouseEvent{}, event_attrs)

      if changeset.valid? do
        previous_user_id = salts[:previous] && generate_user_id(conn, params, salts[:previous])
        event = struct(Plausible.ClickhouseEvent, event_attrs)
        session_id = Plausible.Session.Store.on_event(event, previous_user_id)

        Map.put(event, :session_id, session_id)
        |> Plausible.Event.WriteBuffer.insert()
      else
        {:error, changeset}
      end
    end
  end

  defp get_ip(conn) do
    forwarded_for = List.first(Plug.Conn.get_req_header(conn, "x-forwarded-for"))

    if forwarded_for do
      String.split(forwarded_for, ",")
      |> Enum.map(&String.trim/1)
      |> List.first()
    else
      to_string(:inet_parse.ntoa(conn.remote_ip))
    end
  end

  defp visitor_country(conn) do
    result =
      get_ip(conn)
      |> Geolix.lookup()
      |> Map.get(:country)

    if result && result.country do
      result.country.iso_code
    end
  end

  defp parse_referrer(_, nil), do: nil

  defp parse_referrer(uri, referrer_str) do
    referrer_uri = URI.parse(referrer_str)

    if strip_www(referrer_uri.host) !== strip_www(uri.host) && referrer_uri.host !== "localhost" do
      RefInspector.parse(referrer_str)
    end
  end

  defp generate_user_id(conn, params, salt) do
    user_agent = List.first(Plug.Conn.get_req_header(conn, "user-agent")) || ""
    ip_address = get_ip(conn)
    domain = strip_www(params["domain"]) || ""

    SipHash.hash!(salt, user_agent <> ip_address <> domain)
  end

  defp calculate_screen_size(nil), do: nil
  defp calculate_screen_size(width) when width < 576, do: "Mobile"
  defp calculate_screen_size(width) when width < 992, do: "Tablet"
  defp calculate_screen_size(width) when width < 1440, do: "Laptop"
  defp calculate_screen_size(width) when width >= 1440, do: "Desktop"

  defp clean_referrer(nil), do: nil

  defp clean_referrer(ref) do
    uri = URI.parse(ref.referer)

    if uri && uri.host && uri.scheme in ["http", "https"] do
      host = String.replace_prefix(uri.host, "www.", "")
      path = uri.path || ""
      host <> String.trim_trailing(path, "/")
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

  defp referrer_source(nil), do: nil

  defp referrer_source(ref) do
    case ref.source do
      :unknown ->
        clean_uri(ref.referer)

      source ->
        source
    end
  end

  defp clean_uri(uri) do
    uri = URI.parse(String.trim(uri))

    if uri && uri.host && uri.scheme in ["http", "https"] do
      String.replace_leading(uri.host, "www.", "")
    end
  end
end
