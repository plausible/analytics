defmodule Plausible.Ingestion.Event do
  require OpenTelemetry.Tracer, as: Tracer
  alias Plausible.Ingestion.{Request, CityOverrides}

  @spec build_and_buffer(Request.t(), [atom()], [{atom(), map()}]) ::
          {:ok, [{atom(), map()}]} | :skip | {:error, Ecto.Changeset.t()}
  @doc """
  Builds events from %Plausible.Ingestion.Request{} and adds them to Plausible.Event.WriteBuffer.
  This function reads geolocation data and parses the user agent string. Returns :skip if the
  request is identified as spam, or blocked.

    iex> build_and_buffer(request)
    {:ok, []}

  The `stash` and `apply` options allows given %Plausible.ClickhouseEvent{} fields be used later.
  This is useful when the caller makes two subsequent requests and don't want to re-fetch
  geolocation and user agent dependent fields. Check the following example:

    iex> {:ok, stash} = build_and_buffer(first_request, [:geolocation])
    ...> {:ok, stash} = build_and_buffer(second_request, [:geolocation], stash)
    ...> {:ok, stash} = build_and_buffer(third_request, [:geolocation], stash)
    iex> stash
    [geolocation: %{country_code: "BR"}]

  Currently `stash` only supports `:geolocation` and `:user_agent`, which are the most expensive
  calls.

  """
  def build_and_buffer(%Request{} = request, stash \\ [], apply \\ []) do
    with :ok <- spam_or_blocked?(request),
         salts <- Plausible.Session.Salts.fetch(),
         event <- %Plausible.ClickhouseEvent{},
         %{} = event <-
           apply_stash(event, apply[:user_agent], fn -> put_user_agent(event, request) end),
         %{} = event <- put_basic_info(event, request),
         %{} = event <- put_referrer(event, request),
         %{} = event <-
           apply_stash(event, apply[:geolocation], fn -> put_geolocation(event, request) end),
         %{} = event <- put_screen_size(event, request),
         %{} = event <- put_props(event, request),
         events when is_list(events) <- map_domains(event, request),
         events when is_list(events) <- put_user_id(events, request, salts),
         :ok <- validate_events(events),
         events when is_list(events) <- register_session(events, request, salts),
         stash <- save_stash(events, stash) do
      Enum.each(events, &Plausible.Event.WriteBuffer.insert/1)
      {:ok, stash}
    end
  end

  defp put_basic_info(%Plausible.ClickhouseEvent{} = event, %Request{} = request) do
    uri = request.url && URI.parse(request.url)
    host = if uri && uri.host == "", do: "(none)", else: uri && uri.host

    %Plausible.ClickhouseEvent{
      event
      | timestamp: NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second),
        name: request.event_name,
        hostname: strip_www(host),
        pathname: get_pathname(uri, request.hash_mode)
    }
  end

  defp get_pathname(_uri = nil, _hash_mode), do: "/"

  defp get_pathname(uri, hash_mode) do
    pathname =
      (uri.path || "/")
      |> URI.decode()
      |> String.trim_trailing()

    if hash_mode == 1 && uri.fragment do
      pathname <> "#" <> URI.decode(uri.fragment)
    else
      pathname
    end
  end

  defp put_props(%Plausible.ClickhouseEvent{} = event, %Request{} = request) do
    if is_map(request.props) do
      event
      |> Map.put(:"meta.key", Map.keys(request.props))
      |> Map.put(:"meta.value", Map.values(request.props) |> Enum.map(&to_string/1))
    else
      event
    end
  end

  defp put_referrer(%Plausible.ClickhouseEvent{} = event, %Request{} = request) do
    uri = request.url && URI.parse(request.url)
    ref = parse_referrer(uri, request.referrer)

    %Plausible.ClickhouseEvent{
      event
      | utm_medium: request.utm_medium,
        utm_source: request.utm_source,
        utm_campaign: request.utm_campaign,
        utm_content: request.utm_content,
        utm_term: request.utm_term,
        referrer_source: get_referrer_source(request, ref),
        referrer: clean_referrer(ref)
    }
  end

  defp parse_referrer(_uri, _referrer_str = nil), do: nil

  defp parse_referrer(uri, referrer_str) do
    referrer_uri = URI.parse(referrer_str)

    if strip_www(referrer_uri.host) !== strip_www(uri.host) && referrer_uri.host !== "localhost" do
      RefInspector.parse(referrer_str)
    end
  end

  defp get_referrer_source(request, ref) do
    source = request.utm_source || request.source_param || request.ref_param
    source || PlausibleWeb.RefInspector.parse(ref)
  end

  defp clean_referrer(nil), do: nil

  defp clean_referrer(ref) do
    uri = URI.parse(ref.referer)

    if PlausibleWeb.RefInspector.right_uri?(uri) do
      host = String.replace_prefix(uri.host, "www.", "")
      path = uri.path || ""
      host <> String.trim_trailing(path, "/")
    end
  end

  defp put_user_agent(%Plausible.ClickhouseEvent{} = event, %Request{} = request) do
    case parse_user_agent(request) do
      %UAInspector.Result{client: %UAInspector.Result.Client{name: "Headless Chrome"}} ->
        :skip

      %UAInspector.Result.Bot{} ->
        :skip

      %UAInspector.Result{} = user_agent ->
        %Plausible.ClickhouseEvent{
          event
          | operating_system: os_name(user_agent),
            operating_system_version: os_version(user_agent),
            browser: browser_name(user_agent),
            browser_version: browser_version(user_agent)
        }

      _any ->
        event
    end
  end

  defp parse_user_agent(%Request{user_agent: user_agent}) when is_binary(user_agent) do
    Tracer.with_span "parse_user_agent" do
      case Cachex.fetch(:user_agents, user_agent, &UAInspector.parse/1) do
        {:ok, user_agent} -> user_agent
        {:commit, user_agent} -> user_agent
        _ -> nil
      end
    end
  end

  defp parse_user_agent(request), do: request

  defp browser_name(ua) do
    case ua.client do
      :unknown -> ""
      %UAInspector.Result.Client{name: "Mobile Safari"} -> "Safari"
      %UAInspector.Result.Client{name: "Chrome Mobile"} -> "Chrome"
      %UAInspector.Result.Client{name: "Chrome Mobile iOS"} -> "Chrome"
      %UAInspector.Result.Client{name: "Firefox Mobile"} -> "Firefox"
      %UAInspector.Result.Client{name: "Firefox Mobile iOS"} -> "Firefox"
      %UAInspector.Result.Client{name: "Opera Mobile"} -> "Opera"
      %UAInspector.Result.Client{name: "Opera Mini"} -> "Opera"
      %UAInspector.Result.Client{name: "Opera Mini iOS"} -> "Opera"
      %UAInspector.Result.Client{name: "Yandex Browser Lite"} -> "Yandex Browser"
      %UAInspector.Result.Client{name: "Chrome Webview"} -> "Mobile App"
      %UAInspector.Result.Client{type: "mobile app"} -> "Mobile App"
      client -> client.name
    end
  end

  defp browser_version(ua) do
    case ua.client do
      :unknown -> ""
      %UAInspector.Result.Client{type: "mobile app"} -> ""
      client -> major_minor(client.version)
    end
  end

  defp os_name(ua) do
    case ua.os do
      :unknown -> ""
      os -> os.name
    end
  end

  defp os_version(ua) do
    case ua.os do
      :unknown -> ""
      os -> major_minor(os.version)
    end
  end

  defp major_minor(version) do
    case version do
      :unknown ->
        ""

      version ->
        version
        |> String.split(".")
        |> Enum.take(2)
        |> Enum.join(".")
    end
  end

  defp put_screen_size(%Plausible.ClickhouseEvent{} = event, %Request{} = request) do
    screen_width =
      case request.screen_width do
        nil -> nil
        width when width < 576 -> "Mobile"
        width when width < 992 -> "Tablet"
        width when width < 1440 -> "Laptop"
        width when width >= 1440 -> "Desktop"
      end

    %Plausible.ClickhouseEvent{event | screen_size: screen_width}
  end

  defp put_geolocation(%Plausible.ClickhouseEvent{} = event, %Request{} = request) do
    Tracer.with_span "parse_visitor_location" do
      result = Geolix.lookup(request.remote_ip, where: :geolocation)

      country_code =
        get_in(result, [:country, :iso_code])
        |> ignore_unknown_country()

      city_geoname_id = get_in(result, [:city, :geoname_id])

      subdivision1_code =
        case result do
          %{subdivisions: [%{iso_code: iso_code} | _rest]} ->
            country_code <> "-" <> iso_code

          _ ->
            ""
        end

      subdivision2_code =
        case result do
          %{subdivisions: [_first, %{iso_code: iso_code} | _rest]} ->
            country_code <> "-" <> iso_code

          _ ->
            ""
        end

      %Plausible.ClickhouseEvent{
        event
        | country_code: country_code,
          subdivision1_code: subdivision1_code,
          subdivision2_code: subdivision2_code,
          city_geoname_id: Map.get(CityOverrides.get(), city_geoname_id, city_geoname_id)
      }
    end
  end

  defp ignore_unknown_country("ZZ"), do: nil
  defp ignore_unknown_country(country), do: country

  defp map_domains(%Plausible.ClickhouseEvent{} = event, %Request{} = request) do
    domains =
      if request.domain do
        String.split(request.domain, ",")
        |> Enum.map(&String.trim/1)
        |> Enum.map(&strip_www/1)
      else
        uri = request.url && URI.parse(request.url)
        [strip_www(uri && uri.host)]
      end

    for domain <- domains, do: %Plausible.ClickhouseEvent{event | domain: domain}
  end

  defp put_user_id(events, %Request{} = request, salts) do
    for %Plausible.ClickhouseEvent{} = event <- events do
      user_id = generate_user_id(request, event.domain, event.hostname, salts.current)

      %Plausible.ClickhouseEvent{event | user_id: user_id}
    end
  end

  defp register_session(events, %Request{} = request, salts) do
    for %Plausible.ClickhouseEvent{} = event <- events do
      previous_user_id = generate_user_id(request, event.domain, event.hostname, salts.previous)

      session_id =
        Tracer.with_span "cache_store_event" do
          Plausible.Session.CacheStore.on_event(event, previous_user_id)
        end

      %Plausible.ClickhouseEvent{event | session_id: session_id}
    end
  end

  defp generate_user_id(request, domain, hostname, salt) do
    cond do
      is_nil(salt) ->
        nil

      is_nil(domain) ->
        nil

      true ->
        user_agent = request.user_agent || ""
        root_domain = get_root_domain(hostname)

        SipHash.hash!(salt, user_agent <> request.remote_ip <> domain <> root_domain)
    end
  end

  defp get_root_domain(nil), do: "(none)"

  defp get_root_domain(hostname) do
    case PublicSuffix.registrable_domain(hostname) do
      domain when is_binary(domain) -> domain
      _any -> hostname
    end
  end

  defp spam_or_blocked?(%Request{} = request) do
    cond do
      request.domain in Application.get_env(:plausible, :domain_blacklist) ->
        :skip

      FunWithFlags.enabled?(:block_event_ingest, for: request.domain) ->
        Tracer.set_attribute("blocked_by_flag", true)
        :skip

      request.referrer &&
          URI.parse(request.referrer).host |> strip_www() |> ReferrerBlocklist.is_spammer?() ->
        :skip

      true ->
        :ok
    end
  end

  defp validate_events(events) do
    Enum.reduce_while(events, :ok, fn %Plausible.ClickhouseEvent{} = event, _acc ->
      event
      |> Map.from_struct()
      |> Plausible.ClickhouseEvent.new()
      |> case do
        %Ecto.Changeset{valid?: true} -> {:cont, :ok}
        %Ecto.Changeset{valid?: false} = changeset -> {:halt, {:error, changeset}}
      end
    end)
  end

  defp strip_www(hostname) do
    if hostname do
      String.replace_prefix(hostname, "www.", "")
    else
      nil
    end
  end

  defp apply_stash(%Plausible.ClickhouseEvent{} = event, stashed, fallback_fun) do
    if stashed, do: Map.merge(event, stashed), else: fallback_fun.()
  end

  @stash_mapping [
    user_agent: [:operating_system, :operating_system_version, :browser, :browser_version],
    geolocation: [:country_code, :subdivision1_code, :subdivision2_code, :city_geoname_id]
  ]

  defp save_stash([%Plausible.ClickhouseEvent{} = event | _rest], stash) do
    Enum.map(stash, fn stash_key ->
      event_keys = @stash_mapping[stash_key] || []
      attrs = Map.take(event, event_keys)
      {stash_key, attrs}
    end)
  end
end
