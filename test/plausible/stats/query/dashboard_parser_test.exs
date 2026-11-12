defmodule Plausible.Stats.Query.DashboardParserTest do
  use Plausible.DataCase
  import Plausible.Stats.Query.DashboardParser
  alias Plausible.Stats.QueryError
  alias Plausible.Stats.Query.ParsedParams

  @base_params %{
    "date_range" => "28d",
    "relative_date" => nil,
    "filters" => [],
    "dimensions" => [],
    "metrics" => ["visitors"],
    "include" => %{
      "imports" => true,
      "imports_meta" => false,
      "compare" => nil,
      "compare_match_day_of_week" => true
    }
  }

  describe "input_date_range" do
    test "parses date_range" do
      params = Map.merge(@base_params, %{"date_range" => ["2021-01-01", "2021-03-05"]})
      {:ok, parsed} = parse(params)

      assert %ParsedParams{
               input_date_range: {:date_range, ~D[2021-01-01], ~D[2021-03-05]}
             } = parsed
    end
  end

  describe "relative_date" do
    test "parses relative_date" do
      params = Map.merge(@base_params, %{"relative_date" => "2021-05-05"})
      {:ok, parsed} = parse(params)
      assert %ParsedParams{relative_date: ~D[2021-05-05]} = parsed
    end
  end

  describe "include.imports" do
    test "true -> true" do
      params = %{@base_params | "include" => %{@base_params["include"] | "imports" => true}}
      {:ok, parsed} = parse(params)
      assert parsed.include.imports == true
    end

    test "invalid -> false" do
      params = %{@base_params | "include" => %{@base_params["include"] | "imports" => "foo"}}
      {:ok, parsed} = parse(params)
      assert parsed.include.imports == false
    end

    test "false -> false" do
      params = %{@base_params | "include" => %{@base_params["include"] | "imports" => false}}
      {:ok, parsed} = parse(params)
      assert parsed.include.imports == false
    end
  end

  describe "include.compare" do
    for mode <- [:previous_period, :year_over_year] do
      test "parses #{mode} mode" do
        params = %{
          @base_params
          | "include" => %{@base_params["include"] | "compare" => "#{unquote(mode)}"}
        }

        {:ok, parsed} = parse(params)
        assert parsed.include.compare == unquote(mode)
      end
    end

    test "parses custom date range mode" do
      params = %{
        @base_params
        | "include" => %{@base_params["include"] | "compare" => ["2021-01-01", "2021-04-30"]}
      }

      {:ok, parsed} = parse(params)
      assert parsed.include.compare == {:date_range, ~D[2021-01-01], ~D[2021-04-30]}
    end

    test "fails with invalid custom dates" do
      params = %{
        @base_params
        | "include" => %{@base_params["include"] | "compare" => ["2021-13-01", "2021-04-30"]}
      }

      assert {:error, %QueryError{code: :invalid_include}} = parse(params)
    end

    test "fails with random invalid compare value" do
      params = %{
        @base_params
        | "include" => %{@base_params["include"] | "compare" => "foo"}
      }

      assert {:error, %QueryError{code: :invalid_include}} = parse(params)
    end

    test "compare is nil if not provided" do
      params = %{
        @base_params
        | "include" => Map.drop(@base_params["include"], ["compare"])
      }

      {:ok, parsed} = parse(params)
      assert parsed.include.compare == nil
    end
  end

  describe "include.compare_match_day_of_week" do
    test "true -> true" do
      params = %{
        @base_params
        | "include" => %{@base_params["include"] | "compare_match_day_of_week" => true}
      }

      {:ok, parsed} = parse(params)
      assert parsed.include.compare_match_day_of_week == true
    end

    test "invalid -> false" do
      params = %{
        @base_params
        | "include" => %{@base_params["include"] | "compare_match_day_of_week" => "foo"}
      }

      {:ok, parsed} = parse(params)
      assert parsed.include.compare_match_day_of_week == false
    end

    test "false -> false" do
      params = %{
        @base_params
        | "include" => %{@base_params["include"] | "compare_match_day_of_week" => false}
      }

      {:ok, parsed} = parse(params)
      assert parsed.include.compare_match_day_of_week == false
    end
  end

  describe "dimensions" do
    test "parses breakdown-only dimensions" do
      params = Map.merge(@base_params, %{"dimensions" => ["event:prop_key"]})
      {:ok, parsed} = parse(params)
      assert parsed.dimensions == ["event:prop_key"]
    end
  end

  describe "order_by" do
    test "breakdown-only dimensions can be used in order_by" do
      params =
        Map.merge(@base_params, %{
          "dimensions" => ["event:prop_key"],
          "order_by" => [["event:prop_key", "asc"]]
        })

      {:ok, parsed} = parse(params)
      assert parsed.order_by == [{"event:prop_key", :asc}]
    end
  end

  describe "filters" do
    test "parses valid filters" do
      params =
        Map.merge(@base_params, %{
          "filters" => [
            ["has_not_done", ["is", "event:goal", ["Signup"]]],
            ["contains", "visit:exit_page", ["/:dashboard"]],
            ["is", "visit:source", ["Bing"]],
            ["is_not", "event:props:theme", ["system", "(none)"]]
          ]
        })

      {:ok, parsed} = parse(params)

      assert parsed.filters == [
               [:has_not_done, [:is, "event:goal", ["Signup"]]],
               [:contains, "visit:exit_page", ["/:dashboard"]],
               [:is, "visit:source", ["Bing"]],
               [:is_not, "event:props:theme", ["system", "(none)"]]
             ]
    end

    test "cannot filter by breakdown-only dimensions" do
      params =
        Map.merge(@base_params, %{
          "filters" => [["is", "event:prop_key", ["author"]]]
        })

      {:error, %QueryError{code: :invalid_filters}} = parse(params)
    end

    test "parses city filter with multiple clauses" do
      params =
        Map.merge(@base_params, %{
          "filters" => [["is", "visit:city", ["2988507", "2950159"]]]
        })

      {:ok, parsed} = parse(params)

      assert parsed.filters == [[:is, "visit:city", ["2988507", "2950159"]]]
    end

    test "parses a segment filter" do
      params =
        Map.merge(@base_params, %{
          "filters" => [["is", "segment", [123]]]
        })

      {:ok, parsed} = parse(params)

      assert parsed.filters == [[:is, "segment", [123]]]
    end
  end

  describe "metrics" do
    test "valid metrics" do
      params = Map.merge(@base_params, %{"metrics" => ["visitors", "group_conversion_rate"]})
      assert {:ok, parsed} = parse(params)
      assert parsed.metrics == [:visitors, :group_conversion_rate]
    end

    test "at least one metric required" do
      params = Map.merge(@base_params, %{"metrics" => []})
      assert {:error, %QueryError{code: :invalid_metrics}} = parse(params)
    end
  end

  describe "fixing now" do
    test "now can't be fixed externally via params" do
      params = Map.merge(@base_params, %{"now" => "2026-02-17T10:08:52.272894Z"})
      {:ok, parsed} = parse(params)

      assert parsed.now == nil
    end

    test "now can be fixed as an optional extra argument to parse/2" do
      {:ok, parsed} = parse(@base_params, now: ~U[2026-02-17 10:08:00Z])

      assert parsed.now == ~U[2026-02-17 10:08:00Z]
    end
  end
end
