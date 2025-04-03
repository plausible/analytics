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

  @external_resource "priv/ref_inspector/referers.yml"
  @referers_yaml Application.app_dir(:plausible, "priv/ref_inspector/referers.yml")

  yaml_reader = RefInspector.Config.yaml_file_reader()
  {:ok, db} = RefInspector.Database.Loader.load(@referers_yaml, yaml_reader)
  db = RefInspector.Database.Parser.parse(db)

  lookup =
    Enum.reduce(db, Map.new(), fn {_, entries}, lookup ->
      Enum.reduce(entries, lookup, fn {_, _, _, _, _, _, name}, lookup_inner ->
        Map.put(lookup_inner, String.downcase(name), name)
      end)
    end)

  lookup =
    Enum.reduce(@custom_sources, lookup, fn {key, val}, lookup ->
      lookup
      |> Map.put(key, val)
      |> Map.put(String.downcase(val), val)
    end)

  for {k, v} <- Enum.sort(lookup) do
    def src(unquote(k)), do: unquote(v)
  end

  def src(_), do: nil

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
  """
  def resolve(request) do
    tagged_source =
      request.query_params["utm_source"] ||
        request.query_params["source"] ||
        request.query_params["ref"]

    source =
      cond do
        tagged_source -> tagged_source
        has_valid_referral?(request) -> parse(request.referrer)
        true -> nil
      end

    find_mapping(source)
  end

  def parse(ref) do
    case RefInspector.parse(ref).source do
      :unknown ->
        uri = URI.parse(String.trim(ref))
        format_referrer_host(uri)

      source ->
        source
    end
  end

  def find_mapping(nil), do: nil

  def find_mapping(source) do
    case src(String.downcase(source)) do
      name when is_binary(name) -> name
      _ -> source
    end
  end

  def format_referrer(request) do
    if has_valid_referral?(request) do
      referrer_uri = URI.parse(request.referrer)
      path = String.trim_trailing(referrer_uri.path || "", "/")
      format_referrer_host(referrer_uri) <> path
    end
  end

  defp has_valid_referral?(%Request{referrer: nil}), do: false

  defp has_valid_referral?(%Request{referrer: referrer, uri: uri}) do
    referrer_uri = URI.parse(referrer)

    valid_scheme? = referrer_uri.scheme in ["http", "https", "android-app"]
    valid_host? = !is_nil(referrer_uri.host) && byte_size(referrer_uri.host) > 0

    internal? =
      Request.sanitize_hostname(referrer_uri.host) == Request.sanitize_hostname(uri.host)

    local? = referrer_uri.host == "localhost"

    valid_scheme? and valid_host? and not internal? and not local?
  end

  defp format_referrer_host(uri) do
    protocol = if uri.scheme == "android-app", do: "android-app://", else: ""
    host = String.replace_prefix(uri.host, "www.", "")

    protocol <> host
  end
end
