defmodule Plausible.Stats.QueryParserTest do
  use Plausible.DataCase
  import Plausible.Stats.QueryParser

  setup [:create_user, :create_site]

  test "parsing empty map fails", %{site: site} do
    assert {:error, "#: Required properties site_id, metrics, date_range were not present."} =
             parse(site, :public, %{})
  end

  test "invalid metric passed", %{site: site} do
    params = %{
      "site_id" => site.domain,
      "metrics" => ["visitors", "event:name"],
      "date_range" => "all"
    }

    assert {:error, "#/metrics/1: Invalid metric \"event:name\""} =
             parse(site, :public, params)
  end
end
