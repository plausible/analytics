defmodule Plausible.Ingestion.Source do
  @external_resource "priv/custom_sources.json"
  @custom_sources Application.app_dir(:plausible, "priv/custom_sources.json")
                  |> File.read!()
                  |> Jason.decode!()

  @mapping_overrides [
    {"fb", "Facebook"},
    {"fb-ads", "Facebook"},
    {"fbads", "Facebook"},
    {"fbad", "Facebook"},
    {"facebook-ads", "Facebook"},
    {"facebook_ads", "Facebook"},
    {"fcb", "Facebook"},
    {"facebook_ad", "Facebook"},
    {"facebook_feed_ad", "Facebook"},
    {"ig", "Instagram"},
    {"yt", "Youtube"},
    {"yt-ads", "Youtube"},
    {"reddit-ads", "Reddit"},
    {"google_ads", "Google"},
    {"google-ads", "Google"},
    {"googleads", "Google"},
    {"gads", "Google"},
    {"google ads", "Google"},
    {"adwords", "Google"},
    {"twitter-ads", "Twitter"},
    {"tiktokads", "TikTok"},
    {"tik.tok", "TikTok"},
    {"perplexity", "Perplexity"},
    {"linktree", "Linktree"}
  ]

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

    Enum.each(@mapping_overrides, fn override ->
      :ets.insert(__MODULE__, override)
    end)
  end

  def parse(nil), do: nil

  def parse(ref) do
    case ref.source do
      :unknown ->
        uri = URI.parse(String.trim(ref.referer))

        if right_uri?(uri) do
          format_referrer_host(uri)
          |> maybe_map_to_custom_source()
        end

      source ->
        source
    end
  end

  def find_mapping(source) do
    case :ets.lookup(__MODULE__, String.downcase(source)) do
      [{_, name}] -> name
      _ -> source
    end
  end

  def format_referrer(uri) do
    path = String.trim_trailing(uri.path || "", "/")
    format_referrer_host(uri) <> path
  end

  def right_uri?(%URI{host: nil}), do: false

  def right_uri?(%URI{host: host, scheme: scheme})
      when scheme in ["http", "https", "android-app"] and byte_size(host) > 0,
      do: true

  def right_uri?(_), do: false

  defp format_referrer_host(uri) do
    protocol = if uri.scheme == "android-app", do: "android-app://", else: ""
    host = String.replace_prefix(uri.host, "www.", "")

    protocol <> host
  end

  defp maybe_map_to_custom_source(source) do
    Map.get(@custom_sources, source, source)
  end
end
