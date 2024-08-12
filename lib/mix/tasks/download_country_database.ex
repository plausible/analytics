defmodule Mix.Tasks.DownloadCountryDatabase do
  @moduledoc """
  This task downloads the Country Lite database from DB-IP for self-hosted or development purposes.
  Plausible Cloud runs a paid version of DB-IP with more detailed geolocation data.
  """

  use Mix.Task
  use Plausible.Repo
  require Logger

  # coveralls-ignore-start

  def run(_) do
    Application.ensure_all_started(:httpoison)
    Application.ensure_all_started(:timex)
    this_month = Date.utc_today()
    last_month = Date.shift(this_month, month: -1)
    this_month = this_month |> Date.to_iso8601() |> binary_part(0, 7)
    last_month = last_month |> Date.to_iso8601() |> binary_part(0, 7)
    this_month_url = "https://download.db-ip.com/free/dbip-country-lite-#{this_month}.mmdb.gz"
    last_month_url = "https://download.db-ip.com/free/dbip-country-lite-#{last_month}.mmdb.gz"
    Logger.info("Downloading #{this_month_url}")
    res = HTTPoison.get!(this_month_url)

    res =
      case res.status_code do
        404 ->
          Logger.info("Got 404 for #{this_month_url}, trying #{last_month_url}")
          HTTPoison.get!(last_month_url)

        _ ->
          res
      end

    if res.status_code == 200 do
      File.mkdir("priv/geodb")
      File.write!("priv/geodb/dbip-country.mmdb.gz", res.body)
      Logger.info("Downloaded and saved the database successfully")
    else
      Logger.error("Unable to download and save the database. Response: #{inspect(res)}")
    end
  end
end
