defmodule Plausible.Ingestion.Geolocation do
  @moduledoc false

  def lookup(ip_address) do
    case Plausible.Geo.lookup(ip_address) do
      %{} = entry ->
        country_code =
          entry
          |> get_in(["country", "iso_code"])
          |> ignore_unknown_country()

        city_geoname_id = country_code && get_in(entry, ["city", "geoname_id"])
        city_geoname_id = Plausible.Ingestion.CityOverrides.get(city_geoname_id, city_geoname_id)

        %{
          country_code: country_code,
          subdivision1_code: subdivision1_code(country_code, entry),
          subdivision2_code: subdivision2_code(country_code, entry),
          city_geoname_id: city_geoname_id
        }

      nil ->
        nil
    end
  end

  defp subdivision1_code(country_code, %{"subdivisions" => [%{"iso_code" => iso_code} | _rest]})
       when not is_nil(country_code) do
    country_code <> "-" <> iso_code
  end

  defp subdivision1_code(_, _), do: nil

  defp subdivision2_code(country_code, %{
         "subdivisions" => [_first, %{"iso_code" => iso_code} | _rest]
       })
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
