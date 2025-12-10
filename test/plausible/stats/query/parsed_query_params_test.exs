defmodule Plausible.Stats.ParsedQueryParamsTest do
  use Plausible.DataCase
  alias Plausible.Stats.ParsedQueryParams

  describe "add_or_replace_filter" do
    test "adds filter" do
      initial_params = %ParsedQueryParams{filters: []}
      new_filter = [:is, "event:page", ["/"]]
      new_params = ParsedQueryParams.add_or_replace_filter(initial_params, new_filter)

      assert new_params.filters == [new_filter]
    end

    test "replaces same dimension filter" do
      initial_params = %ParsedQueryParams{
        filters: [[:contains, "event:page", ["blog", "post"]], [:is, "visit:source", ["Google"]]]
      }

      new_filter = [:is, "event:page", ["/blog/some-post"]]
      new_params = ParsedQueryParams.add_or_replace_filter(initial_params, new_filter)

      assert new_params.filters == [
               [:is, "visit:source", ["Google"]],
               new_filter
             ]
    end

    test "replaces custom prop dimension filter" do
      initial_params = %ParsedQueryParams{
        filters: [[:contains, "event:props:path", ["/path"]], [:is, "visit:source", ["Google"]]]
      }

      new_filter = [:is, "event:props:url", ["https://example.com/path"]]
      new_params = ParsedQueryParams.add_or_replace_filter(initial_params, new_filter)

      assert new_params.filters == [
               [:is, "visit:source", ["Google"]],
               new_filter
             ]
    end
  end
end
