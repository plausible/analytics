defmodule Plausible.Geo do
  @moduledoc "Geolocation functions"
  @adapter Application.compile_env!(:plausible, [__MODULE__, :adapter])

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
    @adapter.lookup(ip_address)
  end

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
  def load_db(opts \\ []) do
    @adapter.load_db(opts)
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
    @adapter.database_type()
  end
end
