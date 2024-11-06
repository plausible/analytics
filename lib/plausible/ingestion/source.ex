defmodule Plausible.Ingestion.Source do
  @moduledoc """
  Resolves the `source` dimension from a combination of `referer` header and either `utm_source`, `source`, or `ref` query parameter.

  """
  alias Plausible.Ingestion.Request

  @external_resource "priv/custom_sources.json"
  @custom_sources Application.app_dir(:plausible, "priv/custom_sources.json")
                  |> File.read!()
                  |> Jason.decode!()

  @paid_sources Map.keys(@custom_sources)
                |> Enum.filter(&String.ends_with?(&1, ["ads", "ad"]))
                |> then(&["adwords" | &1])
                |> MapSet.new()

  def init() do
    :ets.new(__MODULE__, [
      :named_table,
      :set,
      :public,
      {:read_concurrency, true}
    ])

    [{"referers.yml", map}] = RefInspector.Database.list(:default)

    Enum.each(map, fn {_, entries} ->
      Enum.each(entries, fn {_, _, _, _, _, _, name} ->
        :ets.insert(__MODULE__, {String.downcase(name), name})
      end)
    end)

    Enum.each(@custom_sources, fn {key, val} ->
      :ets.insert(__MODULE__, {key, val})
      :ets.insert(__MODULE__, {String.downcase(val), val})
    end)
  end

  def paid_sources() do
    @paid_sources |> MapSet.to_list()
  end

  def paid_source?(source) do
    MapSet.member?(@paid_sources, source)
  end

  @doc """
  Resolves the source of a session based on query params and the `Referer` header.

  When a query parameter like `utm_source` is present, it will be prioritized over the `Referer` header. When the URL does not contain a source tag, we fall
  back to using `Referer` to determine the source. This module also takes care of certain transformations to make the data more useful for the user:
  1. The RefInspector library is used to categorize referrers into "known" sources. For example, when the referrer is google.com or google.co.uk,
  it will always be stored as "Google" which is more useful for marketers.
  2. On top of the standard RefInspector behaviour, we also keep a list of `custom_sources.json` which extends it with referrers that we have seen in the wild.
  For example, Wikipedia has many domains that need to be combined into a single known source. These could all in theory be [upstreamed](https://github.com/snowplow-referer-parser/referer-parser).
  3. When a known source is supplied in utm_source (or source, ref) query parameter, we merge it with our known sources in a case-insensitive manner.
  4. Our list of `custom_sources.json` also contains some commonly used utm_source shorthands for certain sources. URL tagging is a mess, and we can never do it
  perfectly, but at least we're making an effort for the most commonly used ones. For example, `ig -> Instagram` and `adwords -> Google`.

  ### Examples:

    iex> alias Plausible.Ingestion.{Source, Request}
    iex> base_request = %Request{uri: URI.parse("https://plausible.io")}
    iex> Source.resolve(%{base_request | referrer: "https://google.com"}) # Known referrer from RefInspector
    "Google"
    iex> Source.resolve(%{base_request | query_params: %{"utm_source" => "google"}}) # Known source from RefInspector supplied as downcased utm_source by user
    "Google"
    iex> Source.resolve(%{base_request | query_params: %{"utm_source" => "GOOGLE"}}) # Known source from RefInspector supplied as uppercased utm_source by user
    "Google"
    iex> Source.resolve(%{base_request | referrer: "https://en.m.wikipedia.org"}) # Known referrer from custom_sources.json
    "Wikipedia"
    iex> Source.resolve(%{base_request | query_params: %{"utm_source" => "wikipedia"}}) # Known source from custom_sources.json supplied as downcased utm_source by user
    "Wikipedia"
    iex> Source.resolve(%{base_request | query_params: %{"utm_source" => "ig"}}) # Known utm_source from custom_sources.json
    "Instagram"
    iex> Source.resolve(%{base_request | referrer: "https://www.markosaric.com"}) # Unknown source, it is just stored as the domain name
    "markosaric.com"
  """
  def resolve(request) do
    tagged_source =
      request.query_params["utm_source"] ||
        request.query_params["source"] ||
        request.query_params["ref"]

    source =
      cond do
        tagged_source -> tagged_source
        has_referral?(request) -> parse(request.referrer)
        true -> nil
      end

    find_mapping(source)
  end

  def parse(ref) do
    case RefInspector.parse(ref).source do
      :unknown ->
        uri = URI.parse(String.trim(ref))

        if valid_referrer?(uri) do
          format_referrer_host(uri)
        end

      source ->
        source
    end
  end

  def find_mapping(nil), do: nil

  def find_mapping(source) do
    case :ets.lookup(__MODULE__, String.downcase(source)) do
      [{_, name}] -> name
      _ -> source
    end
  end

  def format_referrer(nil), do: nil

  def format_referrer(referrer) do
    referrer_uri = URI.parse(referrer)

    if valid_referrer?(referrer_uri) do
      path = String.trim_trailing(referrer_uri.path || "", "/")
      format_referrer_host(referrer_uri) <> path
    end
  end

  defp valid_referrer?(%URI{host: host, scheme: scheme})
       when scheme in ["http", "https", "android-app"] and byte_size(host) > 0,
       do: true

  defp valid_referrer?(_), do: false

  defp has_referral?(%Request{referrer: nil}), do: false

  defp has_referral?(%Request{referrer: referrer, uri: uri}) do
    referrer_uri = URI.parse(referrer)

    Request.sanitize_hostname(referrer_uri.host) !== Request.sanitize_hostname(uri.host) and
      referrer_uri.host !== "localhost"
  end

  defp format_referrer_host(uri) do
    protocol = if uri.scheme == "android-app", do: "android-app://", else: ""
    host = String.replace_prefix(uri.host, "www.", "")

    protocol <> host
  end
end
