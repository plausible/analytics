defmodule Plausible.Geo.Stub do
  @moduledoc false
  @behaviour Plausible.Geo.Adapter

  sample_lookup = %{
    "city" => %{"geoname_id" => 2_988_507, "names" => %{"en" => "Paris"}},
    "continent" => %{"code" => "EU", "geoname_id" => 6_255_148, "names" => %{"en" => "Europe"}},
    "country" => %{
      "geoname_id" => 3_017_382,
      "is_in_european_union" => true,
      "iso_code" => "FR",
      "names" => %{"en" => "France"}
    },
    "location" => %{
      "latitude" => 48.8566,
      "longitude" => 2.35222,
      "time_zone" => "Europe/Paris",
      "weather_code" => "FRXX0076"
    },
    "postal" => %{"code" => "75000"},
    "subdivisions" => [
      %{"geoname_id" => 3_012_874, "iso_code" => "IDF", "names" => %{"en" => "Île-de-France"}},
      %{"geoname_id" => 2_968_815, "iso_code" => "75", "names" => %{"en" => "Paris"}}
    ]
  }

  @lut %{
    {1, 1, 1, 1} => %{"country" => %{"iso_code" => "US"}},
    {2, 2, 2, 2} => sample_lookup,
    {1, 1, 1, 1, 1, 1, 1, 1} => %{"country" => %{"iso_code" => "US"}},
    {0, 0, 0, 0} => %{"country" => %{"iso_code" => "ZZ"}}
  }

  @impl true
  def lookup(ip_address) when is_tuple(ip_address) do
    Map.get(@lut, ip_address)
  end

  def lookup(ip_address) when is_binary(ip_address) do
    {:ok, ip_address} = :inet.parse_address(to_charlist(ip_address))
    lookup(ip_address)
  end

  @impl true
  def load_db(_opts), do: :ok

  @impl true
  def database_type, do: "DBIP-City-Lite"
end
