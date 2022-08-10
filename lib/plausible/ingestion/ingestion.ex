defmodule Plausible.Ingestion do
  require OpenTelemetry.Tracer, as: Tracer

  @no_domain_error {:error, %{domain: ["can't be blank"]}}

  def add_to_buffer(%Plausible.Ingestion.Request{} = request) do
    ua =
      Tracer.with_span "parse_user_agent" do
        parse_user_agent(request)
      end

    blacklist_domain = request.params.domain in Application.get_env(:plausible, :domain_blacklist)

    if blacklist_domain || is_bot?(ua) || is_spammer?(request.params.referrer) ||
         blocked_via_flag?(request.params.domain) do
      :ok
    else
      uri = request.params.url && URI.parse(request.params.url)
      host = if uri && uri.host == "", do: "(none)", else: uri && uri.host

      ref = parse_referrer(uri, request.params.referrer)

      location_details =
        Tracer.with_span "parse_visitor_location" do
          visitor_location_details(request)
        end

      salts = Plausible.Session.Salts.fetch()

      event_attrs = %{
        timestamp: NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second),
        name: request.params.name,
        hostname: strip_www(host),
        pathname: get_pathname(uri, request.params.hash_mode),
        referrer_source: get_referrer_source(request, ref),
        referrer: clean_referrer(ref),
        utm_medium: request.query_params["utm_medium"],
        utm_source: request.query_params["utm_source"],
        utm_campaign: request.query_params["utm_campaign"],
        utm_content: request.query_params["utm_content"],
        utm_term: request.query_params["utm_term"],
        country_code: location_details[:country_code],
        country_geoname_id: location_details[:country_geoname_id],
        subdivision1_code: location_details[:subdivision1_code],
        subdivision2_code: location_details[:subdivision2_code],
        city_geoname_id: location_details[:city_geoname_id],
        operating_system: ua && os_name(ua),
        operating_system_version: ua && os_version(ua),
        browser: ua && browser_name(ua),
        browser_version: ua && browser_version(ua),
        screen_size: calculate_screen_size(request.params.screen_width),
        "meta.key": Map.keys(request.params.meta),
        "meta.value": Map.values(request.params.meta) |> Enum.map(&Kernel.to_string/1)
      }

      Enum.reduce_while(get_domains(request, uri), @no_domain_error, fn domain, _res ->
        user_id = generate_user_id(request, domain, event_attrs[:hostname], salts[:current])

        previous_user_id =
          salts[:previous] &&
            generate_user_id(request, domain, event_attrs[:hostname], salts[:previous])

        changeset =
          event_attrs
          |> Map.merge(%{domain: domain, user_id: user_id})
          |> Plausible.ClickhouseEvent.new()

        if changeset.valid? do
          event = Ecto.Changeset.apply_changes(changeset)

          session_id =
            Tracer.with_span "cache_store_event" do
              Plausible.Session.CacheStore.on_event(event, previous_user_id)
            end

          event
          |> Map.put(:session_id, session_id)
          |> Plausible.Event.WriteBuffer.insert()

          {:cont, :ok}
        else
          errors = Ecto.Changeset.traverse_errors(changeset, &encode_error/1)
          {:halt, {:error, errors}}
        end
      end)
    end
  end

  defp blocked_via_flag?(domain) do
    blocked? = FunWithFlags.enabled?(:block_event_ingest, for: domain)
    Tracer.set_attribute("blocked_by_flag", blocked?)
    blocked?
  end

  # https://hexdocs.pm/ecto/Ecto.Changeset.html#traverse_errors/2-examples
  defp encode_error({msg, opts}) do
    Regex.replace(~r"%{(\w+)}", msg, fn _, key ->
      opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
    end)
  end

  defp is_bot?(%UAInspector.Result.Bot{}), do: true

  defp is_bot?(%UAInspector.Result{client: %UAInspector.Result.Client{name: "Headless Chrome"}}),
    do: true

  defp is_bot?(_), do: false

  defp is_spammer?(nil), do: false

  defp is_spammer?(referrer_str) do
    uri = URI.parse(referrer_str)
    ReferrerBlocklist.is_spammer?(strip_www(uri.host))
  end

  defp get_domains(request, uri) do
    if request.params.domain do
      String.split(request.params.domain, ",")
      |> Enum.map(&String.trim/1)
      |> Enum.map(&strip_www/1)
    else
      List.wrap(strip_www(uri && uri.host))
    end
  end

  defp get_pathname(nil, _), do: "/"

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

  @city_overrides %{
    # Austria
    # Gemeindebezirk Floridsdorf -> Vienna
    2_779_467 => 2_761_369,
    # Gemeindebezirk Leopoldstadt -> Vienna
    2_772_614 => 2_761_369,
    # Gemeindebezirk Landstrasse -> Vienna
    2_773_040 => 2_761_369,
    # Gemeindebezirk Donaustadt -> Vienna
    2_780_851 => 2_761_369,
    # Gemeindebezirk Favoriten -> Vienna
    2_779_776 => 2_761_369,
    # Gemeindebezirk Währing -> Vienna
    2_762_091 => 2_761_369,
    # Gemeindebezirk Wieden -> Vienna
    2_761_393 => 2_761_369,
    # Gemeindebezirk Innere Stadt -> Vienna
    2_775_259 => 2_761_369,
    # Gemeindebezirk Alsergrund -> Vienna
    2_782_729 => 2_761_369,
    # Gemeindebezirk Liesing -> Vienna
    2_772_484 => 2_761_369,
    # Urfahr -> Linz
    2_762_518 => 2_772_400,

    # Canada
    # Old Toronto -> Toronto
    8_436_019 => 6_167_865,
    # Etobicoke -> Toronto
    5_950_267 => 6_167_865,
    # East York -> Toronto
    5_946_235 => 6_167_865,
    # Scarborough -> Toronto
    6_948_711 => 6_167_865,
    # North York -> Toronto
    6_091_104 => 6_167_865,

    # Czech republic
    # Praha 5 -> Prague
    11_951_220 => 3_067_696,
    # Praha 4 -> Prague
    11_951_218 => 3_067_696,
    # Praha 11 -> Prague
    11_951_232 => 3_067_696,
    # Praha 10 -> Prague
    11_951_210 => 3_067_696,
    # Praha 4 -> Prague
    8_378_772 => 3_067_696,

    # Denmark
    # København SV -> Copenhagen
    11_747_123 => 2_618_425,
    # København NV -> Copenhagen
    11_746_894 => 2_618_425,
    # Odense S -> Odense
    11_746_825 => 2_615_876,
    # Odense M -> Odense
    11_746_974 => 2_615_876,
    # Odense SØ -> Odense
    11_746_888 => 2_615_876,
    # Aarhus C -> Aarhus
    11_746_746 => 2_624_652,
    # Aarhus N -> Aarhus
    11_746_890 => 2_624_652,

    # Estonia
    # Kristiine linnaosa -> Tallinn
    11_050_530 => 588_409,
    # Kesklinna linnaosa -> Tallinn
    11_053_706 => 588_409,
    # Lasnamäe linnaosa -> Tallinn
    11_050_526 => 588_409,
    # Põhja-Tallinna linnaosa -> Tallinn
    11_049_594 => 588_409,
    # Mustamäe linnaosa -> Tallinn
    11_050_531 => 588_409,
    # Haabersti linnaosa -> Tallinn
    11_053_707 => 588_409,
    # Viimsi -> Tallinn
    587_629 => 588_409,

    # Germany
    # Bezirk Tempelhof-Schöneberg -> Berlin
    3_336_297 => 2_950_159,
    # Bezirk Mitte -> Berlin
    2_870_912 => 2_950_159,
    # Bezirk Charlottenburg-Wilmersdorf -> Berlin
    3_336_294 => 2_950_159,
    # Bezirk Friedrichshain-Kreuzberg -> Berlin
    3_336_295 => 2_950_159,
    # Moosach -> Munich
    8_351_447 => 2_867_714,
    # Schwabing-Freimann -> Munich
    8_351_448 => 2_867_714,
    # Stadtbezirk 06 -> Düsseldorf
    6_947_276 => 2_934_246,
    # Stadtbezirk 04 -> Düsseldorf
    6_947_274 => 2_934_246,
    # Köln-Ehrenfeld -> Köln
    6_947_479 => 2_886_242,
    # Köln-Lindenthal- -> Köln
    6_947_481 => 2_886_242,
    # Beuel -> Bonn
    2_949_619 => 2_946_447,
    # Innenstadt I -> Frankfurt am Main
    6_946_225 => 2_925_533,

    # India
    # Navi Mumbai -> Mumbai
    6_619_347 => 1_275_339,

    # Mexico
    # Miguel Hidalgo Villa Olímpica -> Mexico city
    11_561_026 => 3_530_597,
    # Zedec Santa Fe -> Mexico city
    3_517_471 => 3_530_597,
    #  Fuentes del Pedregal-> Mexico city
    11_562_596 => 3_530_597,
    #  Centro -> Mexico city
    9_179_691 => 3_530_597,
    #  Cuauhtémoc-> Mexico city
    12_266_959 => 3_530_597,

    # Netherlands
    # Schiphol-Rijk -> Amsterdam
    10_173_838 => 2_759_794,
    # Westpoort -> Amsterdam
    11_525_047 => 2_759_794,
    # Amsterdam-Zuidoost -> Amsterdam
    6_544_881 => 2_759_794,
    # Loosduinen -> The Hague
    11_525_037 => 2_747_373,
    # Laak -> The Hague
    11_525_042 => 2_747_373,

    # Norway
    # Nordre Aker District -> Oslo
    6_940_981 => 3_143_244,

    # Romania
    # Sector 1 -> Bucharest,
    11_055_041 => 683_506,
    # Sector 2 -> Bucharest
    11_055_040 => 683_506,
    # Sector 3 -> Bucharest
    11_055_044 => 683_506,
    # Sector 4 -> Bucharest
    11_055_042 => 683_506,
    # Sector 5 -> Bucharest
    11_055_043 => 683_506,
    # Sector 6 -> Bucharest
    11_055_039 => 683_506,
    # Bucuresti -> Bucharest
    6_691_781 => 683_506,

    # Slovakia
    # Bratislava -> Bratislava
    3_343_955 => 3_060_972,

    # Sweden
    # Södermalm -> Stockholm
    2_676_209 => 2_673_730,

    # Switzerland
    # Vorstädte -> Basel
    11_789_440 => 2_661_604,
    # Zürich (Kreis 11) / Oerlikon -> Zürich
    2_659_310 => 2_657_896,
    # Zürich (Kreis 3) / Alt-Wiedikon -> Zürich
    2_658_007 => 2_657_896,
    # Zürich (Kreis 5) -> Zürich
    6_295_521 => 2_657_896,
    # Zürich (Kreis 1) / Hochschulen -> Zürich
    6_295_489 => 2_657_896,

    # UK
    # Shadwell -> London
    6_690_595 => 2_643_743,
    # City of London -> London
    2_643_741 => 2_643_743,
    # South Bank -> London
    6_545_251 => 2_643_743,
    # Soho -> London
    6_545_173 => 2_643_743,
    # Whitechapel -> London
    2_634_112 => 2_643_743,
    # King's Cross -> London
    6_690_589 => 2_643_743,
    # Poplar -> London
    2_640_091 => 2_643_743,
    # Hackney -> London
    2_647_694 => 2_643_743
  }

  defp visitor_location_details(request) do
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

    %{
      country_code: country_code,
      subdivision1_code: subdivision1_code,
      subdivision2_code: subdivision2_code,
      city_geoname_id: Map.get(@city_overrides, city_geoname_id, city_geoname_id)
    }
  end

  defp ignore_unknown_country("ZZ"), do: nil
  defp ignore_unknown_country(country), do: country

  defp parse_referrer(_, nil), do: nil

  defp parse_referrer(uri, referrer_str) do
    referrer_uri = URI.parse(referrer_str)

    if strip_www(referrer_uri.host) !== strip_www(uri.host) && referrer_uri.host !== "localhost" do
      RefInspector.parse(referrer_str)
    end
  end

  defp generate_user_id(request, domain, hostname, salt) do
    user_agent = request.headers["user-agent"] || ""
    root_domain = get_root_domain(hostname)

    if domain && root_domain do
      SipHash.hash!(salt, user_agent <> request.remote_ip <> domain <> root_domain)
    end
  end

  defp get_root_domain(nil), do: "(none)"

  defp get_root_domain(hostname) do
    case PublicSuffix.registrable_domain(hostname) do
      domain when is_binary(domain) -> domain
      _ -> hostname
    end
  end

  defp calculate_screen_size(nil), do: nil
  defp calculate_screen_size(width) when width < 576, do: "Mobile"
  defp calculate_screen_size(width) when width < 992, do: "Tablet"
  defp calculate_screen_size(width) when width < 1440, do: "Laptop"
  defp calculate_screen_size(width) when width >= 1440, do: "Desktop"

  defp clean_referrer(nil), do: nil

  defp clean_referrer(ref) do
    uri = URI.parse(ref.referer)

    if PlausibleWeb.RefInspector.right_uri?(uri) do
      host = String.replace_prefix(uri.host, "www.", "")
      path = uri.path || ""
      host <> String.trim_trailing(path, "/")
    end
  end

  defp strip_www(nil), do: nil

  defp strip_www(hostname) do
    String.replace_prefix(hostname, "www.", "")
  end

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

  defp major_minor(:unknown), do: ""

  defp major_minor(version) do
    version
    |> String.split(".")
    |> Enum.take(2)
    |> Enum.join(".")
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

  defp get_referrer_source(request, ref) do
    source =
      request.query_params["utm_source"] || request.query_params["source"] ||
        request.query_params["ref"]

    source || PlausibleWeb.RefInspector.parse(ref)
  end

  defp parse_user_agent(%Plausible.Ingestion.Request{} = request) do
    if user_agent = request.headers["user-agent"] do
      res =
        Cachex.fetch(:user_agents, user_agent, fn ua ->
          UAInspector.parse(ua)
        end)

      case res do
        {:ok, user_agent} -> user_agent
        {:commit, user_agent} -> user_agent
        _ -> nil
      end
    end
  end
end
