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
end
