defmodule Plausible.Stats.ApiQueryParserTest do
  use Plausible.DataCase
  import Plausible.Stats.ApiQueryParser

  test "parsing empty map fails" do
    assert {:error, "#: Required properties site_id, metrics, date_range were not present."} =
             parse(%{})
  end

  test "invalid metric passed" do
    params = %{
      "site_id" => "example.com",
      "metrics" => ["visitors", "event:name"],
      "date_range" => "all"
    }

    assert {:error, "#/metrics/1: Invalid metric \"event:name\""} = parse(params)
  end
end
