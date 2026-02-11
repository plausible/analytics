defmodule Plausible.Stats.ApiQueryParserTest do
  use Plausible.DataCase
  import Plausible.Stats.ApiQueryParser
  alias Plausible.Stats.QueryError

  test "parsing empty map fails" do
    assert {:error,
            %QueryError{
              code: :failed_schema_validation,
              message: "#: Required properties site_id, metrics, date_range were not present."
            }} =
             parse(%{})
  end

  test "invalid metric passed" do
    params = %{
      "site_id" => "example.com",
      "metrics" => ["visitors", "event:name"],
      "date_range" => "all"
    }

    assert {:error,
            %QueryError{
              code: :failed_schema_validation,
              message: "#/metrics/1: Invalid metric \"event:name\""
            }} =
             parse(params)
  end

  test "parses 24h date_range shorthand" do
    params = %{
      "site_id" => "example.com",
      "metrics" => ["visitors"],
      "date_range" => "24h"
    }

    assert {:ok, parsed} = parse(params)
    assert parsed.input_date_range == :"24h"
  end
end
