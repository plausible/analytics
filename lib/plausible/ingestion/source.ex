defmodule Plausible.Ingestion.Source do
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

    Enum.each(@custom_sources, fn entry ->
      :ets.insert(__MODULE__, entry)
    end)
  end

  def paid_source?(source) do
    MapSet.member?(@paid_sources, source)
  end

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

  defp has_referral?(%Request{referrer: nil}), do: nil

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
