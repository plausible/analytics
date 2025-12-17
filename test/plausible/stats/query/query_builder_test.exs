defmodule Plausible.Stats.QueryBuilderTest do
  use Plausible.DataCase
  alias Plausible.Stats.{DateTimeRange, ParsedQueryParams, QueryBuilder, Query}

  describe "filter validation" do
    setup [:create_user, :create_site]

    test "event goal name is checked within behavioral filters", %{site: site} do
      insert(:goal, %{site: site, event_name: "Signup"})

      params = %ParsedQueryParams{
        metrics: [:visitors],
        input_date_range: :all,
        filters: [[:has_done, [:is, "event:goal", ["Unknown"]]]]
      }

      assert {:error, error} = QueryBuilder.build(site, params)

      assert error ==
               "Invalid filters. The goal `Unknown` is not configured for this site. Find out how to configure goals here: https://plausible.io/docs/stats-api#filtering-by-goals"
    end
  end
end
