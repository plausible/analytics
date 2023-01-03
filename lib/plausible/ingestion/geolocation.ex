defmodule Plausible.Ingestion.Geolocation do
  @moduledoc false
  alias Plausible.Ingestion.CityOverrides

  def lookup(remote_ip) do
    result = Geolix.lookup(remote_ip, where: :geolocation)

    country_code =
      get_in(result, [:country, :iso_code])
      |> ignore_unknown_country()

    city_geoname_id = country_code && get_in(result, [:city, :geoname_id])
    city_geoname_id = CityOverrides.get(city_geoname_id, city_geoname_id)

    %{
      country_code: country_code,
      subdivision1_code: subdivision1_code(country_code, result),
      subdivision2_code: subdivision2_code(country_code, result),
      city_geoname_id: city_geoname_id
    }
  end

  defp subdivision1_code(country_code, %{subdivisions: [%{iso_code: iso_code} | _rest]})
       when not is_nil(country_code) do
    country_code <> "-" <> iso_code
  end

  defp subdivision1_code(_, _), do: nil

  defp subdivision2_code(country_code, %{subdivisions: [_first, %{iso_code: iso_code} | _rest]})
       when not is_nil(country_code) do
    country_code <> "-" <> iso_code
  end

  defp subdivision2_code(_, _), do: nil

  @ignored_countries [
    # Worldwide
    "ZZ",
    # Disputed territory
    "XX",
    # Tor exit node
    "T1"
  ]
  defp ignore_unknown_country(code) when code in @ignored_countries, do: nil
  defp ignore_unknown_country(country), do: country
end
