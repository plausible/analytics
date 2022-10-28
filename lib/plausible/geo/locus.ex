defmodule Plausible.Geo.Locus do
  @moduledoc false
  @behaviour Plausible.Geo.Adapter
  @db :geolocation

  @impl true
  def load_db(opts) do
    cond do
      license_key = opts[:license_key] ->
        edition = opts[:edition] || "GeoLite2-City"
        :ok = :locus.start_loader(@db, {:maxmind, edition}, license_key: license_key)

      path = opts[:path] ->
        :ok = :locus.start_loader(@db, path)

      true ->
        raise "failed to load geolocation db: need :path or :license_key to be provided"
    end

    unless opts[:async] do
      {:ok, _version} = :locus.await_loader(@db)
    end

    :ok
  end

  @impl true
  def database_type do
    case :locus.get_info(@db, :metadata) do
      {:ok, %{database_type: type}} -> type
      _other -> nil
    end
  end

  @impl true
  def lookup(ip_address) do
    case :locus.lookup(@db, ip_address) do
      {:ok, entry} ->
        entry

      :not_found ->
        nil

      {:error, reason} ->
        raise "failed to lookup ip address #{inspect(ip_address)}: " <> inspect(reason)
    end
  end
end
