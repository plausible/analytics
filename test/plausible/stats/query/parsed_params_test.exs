defmodule Plausible.Stats.Query.ParsedParamsTest do
  use Plausible.DataCase
  alias Plausible.Stats.Query.ParsedParams

  describe "add_or_replace_filter" do
    test "adds filter" do
      initial_params = %ParsedParams{filters: []}
      new_filter = [:is, "event:page", ["/"]]
      new_params = ParsedParams.add_or_replace_filter(initial_params, new_filter)

      assert new_params.filters == [new_filter]
    end

    test "replaces same dimension filter" do
      initial_params = %ParsedParams{
        filters: [[:contains, "event:page", ["blog", "post"]], [:is, "visit:source", ["Google"]]]
      }

      new_filter = [:is, "event:page", ["/blog/some-post"]]
      new_params = ParsedParams.add_or_replace_filter(initial_params, new_filter)

      assert new_params.filters == [
               [:is, "visit:source", ["Google"]],
               new_filter
             ]
    end

    test "replaces custom prop dimension filter" do
      initial_params = %ParsedParams{
        filters: [[:contains, "event:props:path", ["/path"]], [:is, "visit:source", ["Google"]]]
      }

      new_filter = [:is, "event:props:url", ["https://example.com/path"]]
      new_params = ParsedParams.add_or_replace_filter(initial_params, new_filter)

      assert new_params.filters == [
               [:is, "visit:source", ["Google"]],
               new_filter
             ]
    end
  end
end
