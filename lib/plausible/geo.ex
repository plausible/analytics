defmodule Plausible.Geo do
  @moduledoc """
  This module provides an API for fetching IP geolocation.
  """

  require Logger

  @db :geolocation

  @doc """
  Starts the geodatabase loading process. Two modes are supported: local file
  and MaxMind license key.

  ## Options

    * `:path` - the path to the .mmdb database local file. When present,
      `:license_key` and `:edition` are not required.

    * `:license_key` - the [license key](https://support.maxmind.com/hc/en-us/articles/4407111582235-Generate-a-License-Key)
      from MaxMind to authenticate requests to MaxMind.

    * `:edition` - the name of the MaxMind database to be downloaded from MaxMind
      servers. Defaults to `GeoLite2-City`.

    * `:cache_dir` - if set, the downloaded .mmdb files are cached there across
      restarts.

    * `:async` - when used, configures the database loading to run
      asynchronously.

  ## Examples

    Loading from a local file:

      iex> load_db(path: "/etc/plausible/dbip-city.mmdb")
      :ok

    Downloading a MaxMind DB (this license key is no longer active):

      iex> load_db(license_key: "LNpsJCCKPis6XvBP", edition: "GeoLite2-City", async: true)
      :ok

  """
  def load_db(opts) do
    cond do
      license_key = opts[:license_key] ->
        edition = opts[:edition] || "GeoLite2-City"
        maxmind_opts = [license_key: license_key]

        loader_opts =
          if is_binary(opts[:cache_dir]) do
            [
              database_cache_file:
                String.to_charlist(Path.join(opts[:cache_dir], edition <> ".mmdb.gz"))
            ]
          else
            [:no_cache]
          end

        :ok = :locus.start_loader(@db, {:maxmind, edition}, maxmind_opts ++ loader_opts)

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

  @doc """
  Waits for the database to start after calling `load_db/1` with the async option.
  """
  def await_loader, do: :locus.await_loader(@db)

  @doc """
  Returns geodatabase type.

  Used for deciding whether to show the DB-IP disclaimer or not.

  ## Examples

    In the case of a DB-IP database:

      iex> database_type()
      "DBIP-City-Lite"

    In the case of a MaxMind database:

      iex> database_type()
      "GeoLite2-City"

  """
  def database_type do
    case :locus.get_info(@db, :metadata) do
      {:ok, %{database_type: type}} -> type
      _other -> nil
    end
  end

  @doc """
  Looks up geo info about an IP address.

  ## Examples

      iex> lookup("8.7.6.5")
      %{
        "city" => %{
          "geoname_id" => 5349755,
          "names" => %{
            "de" => "Fontana",
            "en" => "Fontana",
            "ja" => "フォンタナ",
            "ru" => "Фонтана"
          }
        },
        "continent" => %{
          "code" => "NA",
          "geoname_id" => 6255149,
          "names" => %{
            "de" => "Nordamerika",
            "en" => "North America",
            "es" => "Norteamérica",
            "fr" => "Amérique du Nord",
            "ja" => "北アメリカ",
            "pt-BR" => "América do Norte",
            "ru" => "Северная Америка",
            "zh-CN" => "北美洲"
          }
        },
        "country" => %{
          "geoname_id" => 6252001,
          "iso_code" => "US",
          "names" => %{
            "de" => "Vereinigte Staaten",
            "en" => "United States",
            "es" => "Estados Unidos",
            "fr" => "États Unis",
            "ja" => "アメリカ",
            "pt-BR" => "EUA",
            "ru" => "США",
            "zh-CN" => "美国"
          }
        },
        "location" => %{
          "accuracy_radius" => 50,
          "latitude" => 34.1211,
          "longitude" => -117.4362,
          "metro_code" => 803,
          "time_zone" => "America/Los_Angeles"
        },
        "postal" => %{"code" => "92336"},
        "registered_country" => %{
          "geoname_id" => 6252001,
          "iso_code" => "US",
          "names" => %{
            "de" => "Vereinigte Staaten",
            "en" => "United States",
            "es" => "Estados Unidos",
            "fr" => "États Unis",
            "ja" => "アメリカ",
            "pt-BR" => "EUA",
            "ru" => "США",
            "zh-CN" => "美国"
          }
        },
        "subdivisions" => [
          %{
            "geoname_id" => 5332921,
            "iso_code" => "CA",
            "names" => %{
              "de" => "Kalifornien",
              "en" => "California",
              "es" => "California",
              "fr" => "Californie",
              "ja" => "カリフォルニア州",
              "pt-BR" => "Califórnia",
              "ru" => "Калифорния",
              "zh-CN" => "加州"
            }
          }
        ]
      }

  """
  def lookup(ip_address) do
    case :locus.lookup(@db, ip_address) do
      {:ok, entry} ->
        entry

      :not_found ->
        nil

      {:error, {:invalid_address, _address}} ->
        nil

      {:error, reason} ->
        Logger.error("Failed to lookup IP address. Reason: " <> inspect(reason))
        nil
    end
  end
end
