defmodule Plausible.Stats.Filters.ParserTest do
  use ExUnit.Case, async: true
  alias Plausible.Stats.{Filters, QueryError}

  describe "parse/1" do
    test "parses valid filters" do
      filters = [
        ["has_not_done", ["is", "event:goal", ["Signup"]]],
        ["contains", "visit:exit_page", ["/:dashboard"]],
        ["is", "visit:source", ["Bing"]],
        ["is_not", "event:props:theme", ["system", "(none)"]]
      ]

      assert Filters.Parser.parse(filters) ==
               {:ok,
                [
                  [:has_not_done, [:is, "event:goal", ["Signup"]]],
                  [:contains, "visit:exit_page", ["/:dashboard"]],
                  [:is, "visit:source", ["Bing"]],
                  [:is_not, "event:props:theme", ["system", "(none)"]]
                ]}
    end

    test "cannot filter by breakdown-only dimensions" do
      assert {:error, %QueryError{code: :invalid_filters}} =
               Filters.Parser.parse([["is", "event:prop_key", ["author"]]])
    end

    test "parses city filter with multiple clauses" do
      assert Filters.Parser.parse([["is", "visit:city", ["2988507", "2950159"]]]) ==
               {:ok, [[:is, "visit:city", ["2988507", "2950159"]]]}
    end

    test "parses a segment filter" do
      assert Filters.Parser.parse([["is", "segment", [123]]]) ==
               {:ok, [[:is, "segment", [123]]]}
    end
  end

  describe "parse_filter_dimension/1" do
    for prop <- Filters.event_props() do
      test "accepts event:#{prop}" do
        dimension = "event:#{unquote(prop)}"
        assert Filters.Parser.parse_filter_dimension(dimension) == {:ok, dimension}
      end
    end

    for prop <- Filters.visit_props() do
      test "accepts visit:#{prop}" do
        dimension = "visit:#{unquote(prop)}"
        assert Filters.Parser.parse_filter_dimension(dimension) == {:ok, dimension}
      end
    end

    test "accepts a custom property" do
      assert Filters.Parser.parse_filter_dimension("event:props:author") ==
               {:ok, "event:props:author"}
    end

    test "accepts segment" do
      assert Filters.Parser.parse_filter_dimension("segment") == {:ok, "segment"}
    end

    for dimension <- [
          "event:props:",
          "event:unknown",
          "event:prop_key",
          "visit:unknown",
          "time:day",
          "unknown"
        ] do
      test "rejects #{dimension}" do
        assert Filters.Parser.parse_filter_dimension(unquote(dimension)) ==
                 {:error, :invalid_filter_dimension}
      end
    end
  end
end
