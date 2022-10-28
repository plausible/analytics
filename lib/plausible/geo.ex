defmodule Plausible.Geo do
  @moduledoc "Geolocation functions"
  @db :geolocation

  @doc """
  Starts the geodatabase loading process. Two options are supported, local file and maxmind key.

  Loading a local file:

      iex> load_db(path: "/etc/plausible/dbip-city.mmdb")
      :ok

  Loading a maxmind db:

      # this license key is no longer active
      iex> load_db(license_key: "LNpsJCCKPis6XvBP", edition: "GeoLite2-City", async: true)
      :ok

  """
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

  @doc """
  Returns geodatabase type. Used for deciding whether to show the DBIP disclaimer.

  Example:

      # in the case of a dbip db
      iex> database_type()
      "DBIP-City-Lite"

      # in the case of a maxmind db
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
  Looks up geo info about an ip address.

  Example:

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

      {:error, reason} ->
        raise "failed to lookup ip address #{inspect(ip_address)}: " <> inspect(reason)
    end
  end
end
