defmodule Plausible.Ingestion.Geolocation do
  alias Plausible.Ingestion.CityOverrides

  def lookup(remote_ip) do
    result = Geolix.lookup(remote_ip, where: :geolocation)

    country_code =
      get_in(result, [:country, :iso_code])
      |> ignore_unknown_country()

    city_geoname_id = get_in(result, [:city, :geoname_id])
    city_geoname_id = Map.get(CityOverrides.get(), city_geoname_id, city_geoname_id)

    subdivision1_code =
      case result do
        %{subdivisions: [%{iso_code: iso_code} | _rest]} ->
          country_code <> "-" <> iso_code

        _ ->
          ""
      end

    subdivision2_code =
      case result do
        %{subdivisions: [_first, %{iso_code: iso_code} | _rest]} ->
          country_code <> "-" <> iso_code

        _ ->
          ""
      end

    %{
      country_code: country_code,
      subdivision1_code: subdivision1_code,
      subdivision2_code: subdivision2_code,
      city_geoname_id: city_geoname_id
    }
  end

  @ignored_countries [
    # Worldwide
    "ZZ",
    # Disputed territory
    "XX",
    # Tor exit node
    "T1"
  ]
  # ZZ - worldwide
  defp ignore_unknown_country(code) when code in @ignored_countries, do: nil
  defp ignore_unknown_country(country), do: country
end
