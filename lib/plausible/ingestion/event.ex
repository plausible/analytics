defmodule Plausible.Ingestion.Event do
  @moduledoc """
  This module exposes the `build_and_buffer/1` function capable of
  turning %Plausible.Ingestion.Request{} into a series of events that in turn
  are uniformly either buffered in batches (to Clickhouse) or dropped
  (e.g. due to spam blocklist) from the processing pipeline.
  """
  alias Plausible.Ingestion.Request
  alias Plausible.ClickhouseEventV2
  alias Plausible.Site.GateKeeper

  defstruct domain: nil,
            site: nil,
            clickhouse_event_attrs: %{},
            clickhouse_event: nil,
            dropped?: false,
            drop_reason: nil,
            request: nil,
            salts: nil,
            changeset: nil

  @type drop_reason() ::
          :bot
          | :spam_referrer
          | GateKeeper.policy()
          | :invalid

  @type t() :: %__MODULE__{
          domain: String.t() | nil,
          site: %Plausible.Site{} | nil,
          clickhouse_event_attrs: map(),
          clickhouse_event: %ClickhouseEventV2{} | nil,
          dropped?: boolean(),
          drop_reason: drop_reason(),
          request: Request.t(),
          salts: map(),
          changeset: %Ecto.Changeset{}
        }

  @spec build_and_buffer(Request.t()) :: {:ok, %{buffered: [t()], dropped: [t()]}}
  def build_and_buffer(%Request{domains: domains} = request) do
    processed_events =
      if spam_referrer?(request) do
        for domain <- domains, do: drop(new(domain, request), :spam_referrer)
      else
        Enum.reduce(domains, [], fn domain, acc ->
          case GateKeeper.check(domain) do
            {:allow, site} ->
              processed =
                domain
                |> new(site, request)
                |> process_unless_dropped(pipeline())

              [processed | acc]

            {:deny, reason} ->
              [drop(new(domain, request), reason) | acc]
          end
        end)
      end

    {dropped, buffered} = Enum.split_with(processed_events, & &1.dropped?)
    {:ok, %{dropped: dropped, buffered: buffered}}
  end

  @spec telemetry_event_buffered() :: [atom()]
  def telemetry_event_buffered() do
    [:plausible, :ingest, :event, :buffered]
  end

  @spec telemetry_event_dropped() :: [atom()]
  def telemetry_event_dropped() do
    [:plausible, :ingest, :event, :dropped]
  end

  @spec emit_telemetry_buffered(t()) :: :ok
  def emit_telemetry_buffered(event) do
    :telemetry.execute(telemetry_event_buffered(), %{}, %{
      domain: event.domain,
      request_timestamp: event.request.timestamp
    })
  end

  @spec emit_telemetry_dropped(t(), drop_reason()) :: :ok
  def emit_telemetry_dropped(event, reason) do
    :telemetry.execute(telemetry_event_dropped(), %{}, %{
      domain: event.domain,
      reason: reason,
      request_timestamp: event.request.timestamp
    })
  end

  defp pipeline() do
    [
      &put_user_agent/1,
      &put_basic_info/1,
      &put_referrer/1,
      &put_utm_tags/1,
      &put_geolocation/1,
      &put_props/1,
      &put_revenue/1,
      &put_salts/1,
      &put_user_id/1,
      &validate_clickhouse_event/1,
      &register_session/1,
      &write_to_buffer/1
    ]
  end

  defp process_unless_dropped(%__MODULE__{} = initial_event, pipeline) do
    Enum.reduce_while(pipeline, initial_event, fn pipeline_step, acc_event ->
      case pipeline_step.(acc_event) do
        %__MODULE__{dropped?: true} = dropped -> {:halt, dropped}
        %__MODULE__{dropped?: false} = event -> {:cont, event}
      end
    end)
  end

  defp new(domain, request) do
    struct!(__MODULE__, domain: domain, request: request)
  end

  defp new(domain, site, request) do
    struct!(__MODULE__, domain: domain, site: site, request: request)
  end

  defp drop(%__MODULE__{} = event, reason, attrs \\ []) do
    fields =
      attrs
      |> Keyword.put(:dropped?, true)
      |> Keyword.put(:drop_reason, reason)

    emit_telemetry_dropped(event, reason)
    struct!(event, fields)
  end

  defp update_attrs(%__MODULE__{} = event, %{} = attrs) do
    struct!(event, clickhouse_event_attrs: Map.merge(event.clickhouse_event_attrs, attrs))
  end

  defp put_user_agent(%__MODULE__{} = event) do
    case parse_user_agent(event.request) do
      %UAInspector.Result{client: %UAInspector.Result.Client{name: "Headless Chrome"}} ->
        drop(event, :bot)

      %UAInspector.Result.Bot{} ->
        drop(event, :bot)

      %UAInspector.Result{} = user_agent ->
        update_attrs(event, %{
          operating_system: os_name(user_agent),
          operating_system_version: os_version(user_agent),
          browser: browser_name(user_agent),
          browser_version: browser_version(user_agent),
          screen_size: screen_size(user_agent)
        })

      _any ->
        event
    end
  end

  defp put_basic_info(%__MODULE__{} = event) do
    update_attrs(event, %{
      domain: event.domain,
      site_id: event.site.id,
      timestamp: event.request.timestamp,
      name: event.request.event_name,
      hostname: event.request.hostname,
      pathname: event.request.pathname
    })
  end

  defp put_referrer(%__MODULE__{} = event) do
    ref = parse_referrer(event.request.uri, event.request.referrer)

    update_attrs(event, %{
      referrer_source: get_referrer_source(event.request, ref),
      referrer: clean_referrer(ref)
    })
  end

  defp put_utm_tags(%__MODULE__{} = event) do
    query_params = event.request.query_params

    update_attrs(event, %{
      utm_medium: query_params["utm_medium"],
      utm_source: query_params["utm_source"],
      utm_campaign: query_params["utm_campaign"],
      utm_content: query_params["utm_content"],
      utm_term: query_params["utm_term"]
    })
  end

  defp put_geolocation(%__MODULE__{} = event) do
    result = Plausible.Ingestion.Geolocation.lookup(event.request.remote_ip) || %{}

    update_attrs(event, result)
  end

  defp put_props(%__MODULE__{request: %{props: %{} = props}} = event) do
    update_attrs(event, %{
      "meta.key": Map.keys(props),
      "meta.value": Enum.map(props, fn {_, v} -> to_string(v) end)
    })
  end

  defp put_props(%__MODULE__{} = event), do: event

  defp put_revenue(%__MODULE__{request: %{revenue_source: %Money{} = revenue_source}} = event) do
    matching_goal =
      Enum.find(event.site.revenue_goals, &(&1.event_name == event.clickhouse_event_attrs.name))

    cond do
      is_nil(matching_goal) ->
        event

      matching_goal.currency == revenue_source.currency ->
        update_attrs(event, %{
          revenue_source_amount: Money.to_decimal(revenue_source),
          revenue_source_currency: to_string(revenue_source.currency),
          revenue_reporting_amount: Money.to_decimal(revenue_source),
          revenue_reporting_currency: to_string(revenue_source.currency)
        })

      matching_goal.currency != revenue_source.currency ->
        converted = Money.to_currency!(revenue_source, matching_goal.currency)

        update_attrs(event, %{
          revenue_source_amount: Money.to_decimal(revenue_source),
          revenue_source_currency: to_string(revenue_source.currency),
          revenue_reporting_amount: Money.to_decimal(converted),
          revenue_reporting_currency: to_string(converted.currency)
        })
    end
  end

  defp put_revenue(event), do: event

  defp put_salts(%__MODULE__{} = event) do
    %{event | salts: Plausible.Session.Salts.fetch()}
  end

  defp put_user_id(%__MODULE__{} = event) do
    update_attrs(event, %{
      user_id:
        generate_user_id(
          event.request,
          event.domain,
          event.clickhouse_event_attrs.hostname,
          event.salts.current
        )
    })
  end

  defp validate_clickhouse_event(%__MODULE__{} = event) do
    clickhouse_event =
      event
      |> Map.fetch!(:clickhouse_event_attrs)
      |> ClickhouseEventV2.new()

    case Ecto.Changeset.apply_action(clickhouse_event, nil) do
      {:ok, valid_clickhouse_event} ->
        %{event | clickhouse_event: valid_clickhouse_event}

      {:error, changeset} ->
        drop(event, :invalid, changeset: changeset)
    end
  end

  defp register_session(%__MODULE__{} = event) do
    previous_user_id =
      generate_user_id(
        event.request,
        event.domain,
        event.clickhouse_event.hostname,
        event.salts.previous
      )

    session_id = Plausible.Session.CacheStore.on_event(event.clickhouse_event, previous_user_id)

    clickhouse_event = Map.put(event.clickhouse_event, :session_id, session_id)
    %{event | clickhouse_event: clickhouse_event}
  end

  defp write_to_buffer(%__MODULE__{clickhouse_event: clickhouse_event} = event) do
    {:ok, _} = Plausible.Event.WriteBuffer.insert(clickhouse_event)
    emit_telemetry_buffered(event)
    event
  end

  defp parse_referrer(_uri, _referrer_str = nil), do: nil

  defp parse_referrer(uri, referrer_str) do
    referrer_uri = URI.parse(referrer_str)

    if Request.sanitize_hostname(referrer_uri.host) !== Request.sanitize_hostname(uri.host) &&
         referrer_uri.host !== "localhost" do
      RefInspector.parse(referrer_str)
    end
  end

  defp get_referrer_source(request, ref) do
    source =
      request.query_params["utm_source"] ||
        request.query_params["source"] ||
        request.query_params["ref"]

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

  defp parse_user_agent(%Request{user_agent: user_agent}) when is_binary(user_agent) do
    case Cachex.fetch(:user_agents, user_agent, &UAInspector.parse/1) do
      {:ok, user_agent} -> user_agent
      {:commit, user_agent} -> user_agent
      _ -> nil
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

  @mobile_types [
    "smartphone",
    "feature phone",
    "portable media player",
    "phablet",
    "wearable",
    "camera"
  ]
  @tablet_types ["car browser", "tablet"]
  @desktop_types ["tv", "console", "desktop"]
  alias UAInspector.Result.Device
  # credo:disable-for-next-line Credo.Check.Refactor.CyclomaticComplexity
  defp screen_size(ua) do
    case ua.device do
      %Device{type: t} when t in @mobile_types ->
        "Mobile"

      %Device{type: t} when t in @tablet_types ->
        "Tablet"

      %Device{type: t} when t in @desktop_types ->
        "Desktop"

      %Device{type: :unknown} ->
        nil

      %Device{type: type} ->
        Sentry.capture_message("Could not determine device type from UAInspector",
          extra: %{type: type}
        )

        nil

      _ ->
        nil
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

  defp spam_referrer?(%Request{referrer: referrer}) when is_binary(referrer) do
    URI.parse(referrer).host
    |> Request.sanitize_hostname()
    |> ReferrerBlocklist.is_spammer?()
  end

  defp spam_referrer?(_), do: false
end
