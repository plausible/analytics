defmodule Plausible.Stats.Query.BuilderTest do
  use Plausible.DataCase
  alias Plausible.Stats.{DateTimeRange, Query, QueryError}
  alias Plausible.Stats.Query.ParsedParams

  setup [:create_user, :create_site]

  describe "filter validation" do
    for operation <- [
          :is,
          :is_not,
          :matches_wildcard,
          :matches_wildcard_not,
          :matches,
          :matches_not,
          :contains,
          :contains_not
        ] do
      test "valid simple #{operation} filter passes validation", %{site: site} do
        params = %ParsedParams{
          metrics: [:visitors],
          input_date_range: :all,
          filters: [[unquote(operation), "event:name", ["foo"]]]
        }

        assert {:ok, query} = Query.Builder.build(site, params)

        assert_matches %Query{filters: [[^unquote(operation), "event:name", ["foo"]]]} = query
      end

      test "valid complex nested #{operation} filter passes validation", %{site: site} do
        params = %ParsedParams{
          metrics: [:visitors],
          input_date_range: :all,
          filters: [
            [
              :not,
              [
                :and,
                [
                  [unquote(operation), "event:name", ["foo"]],
                  [unquote(operation), "event:name", ["bar"]]
                ]
              ]
            ]
          ]
        }

        assert {:ok, query} = Query.Builder.build(site, params)

        assert_matches %Query{
                         filters: [
                           [
                             :not,
                             [
                               :and,
                               [
                                 [unquote(operation), "event:name", ["foo"]],
                                 [unquote(operation), "event:name", ["bar"]]
                               ]
                             ]
                           ]
                         ]
                       } = query
      end
    end

    test "event goal name is checked within behavioral filters", %{site: site} do
      insert(:goal, %{site: site, event_name: "Signup"})

      params = %ParsedParams{
        metrics: [:visitors],
        input_date_range: :all,
        filters: [[:has_done, [:is, "event:goal", ["Unknown"]]]]
      }

      assert {:error, %QueryError{message: error}} = Query.Builder.build(site, params)

      assert error ==
               "Invalid filters. The goal `Unknown` is not configured for this site. Find out how to configure goals here: https://plausible.io/docs/stats-api#filtering-by-goals"
    end

    for operation <- [:matches, :matches_not, :matches_wildcard, :matches_wildcard_not] do
      test "case_sensitive modifier is not valid for #{operation}", %{site: site} do
        assert {:error, %QueryError{message: error}} =
                 Query.Builder.build(site, %ParsedParams{
                   metrics: [:visitors],
                   input_date_range: :all,
                   filters: [
                     [unquote(operation), "event:page", ["a"], %{case_insensitive: true}]
                   ]
                 })

        assert error =~ "Invalid filters."
        assert error =~ "case_sensitive modifier is not allowed with pattern operators"
        assert error =~ Atom.to_string(unquote(operation))
      end
    end

    test "prohibits case_sensitive modifier with pattern operator in a complex filter tree", %{
      site: site
    } do
      assert {:error, %QueryError{message: error}} =
               Query.Builder.build(site, %ParsedParams{
                 metrics: [:visitors],
                 input_date_range: :all,
                 filters: [
                   [
                     :or,
                     [
                       [
                         :and,
                         [
                           [:is, "visit:city_name", ["London"]],
                           [:not, [:is, "visit:country_name", ["Canada"]]]
                         ]
                       ],
                       [:matches, "event:page", ["a"], %{case_insensitive: true}]
                     ]
                   ]
                 ]
               })

      assert error =~ "Invalid filters."
      assert error =~ "case_sensitive modifier is not allowed with pattern operators"
      assert error =~ ":matches"
    end
  end

  describe "date range" do
    test "builds utc_time_range from input_date_range and relative_date", %{site: site} do
      assert {:ok, query} =
               Query.Builder.build(site, %ParsedParams{
                 metrics: [:visitors],
                 input_date_range: :month,
                 relative_date: ~D[2021-05-05]
               })

      assert query.utc_time_range == %DateTimeRange{
               first: ~U[2021-05-01 00:00:00Z],
               last: ~U[2021-05-31 23:59:59Z]
             }
    end
  end

  describe "exit_rate metric" do
    test "fails validation without visit:exit_page dimension", %{site: site} do
      assert {:error, %QueryError{message: error}} =
               Query.Builder.build(site, %ParsedParams{
                 metrics: [:exit_rate],
                 input_date_range: :all
               })

      assert error ==
               "Metric `exit_rate` requires a `\"visit:exit_page\"` dimension. No other dimensions are allowed."
    end

    test "fails validation with event only filters", %{site: site} do
      assert {:error, %QueryError{message: error}} =
               Query.Builder.build(site, %ParsedParams{
                 metrics: [:exit_rate],
                 dimensions: ["visit:exit_page"],
                 filters: [[:is, "event:page", ["/"]]],
                 input_date_range: :all
               })

      assert error == "Metric `exit_rate` cannot be queried when filtering on event dimensions."
    end

    test "fails validation with event metrics", %{site: site} do
      assert {:error, %QueryError{message: error}} =
               Query.Builder.build(site, %ParsedParams{
                 metrics: [:exit_rate, :pageviews],
                 dimensions: ["visit:exit_page"],
                 input_date_range: :all
               })

      assert error ==
               "Event metric(s) `pageviews` cannot be queried along with session dimension(s) `visit:exit_page`"
    end

    test "passes validation", %{site: site} do
      assert {:ok, query} =
               Query.Builder.build(site, %ParsedParams{
                 metrics: [:exit_rate],
                 dimensions: ["visit:exit_page"],
                 input_date_range: :all
               })

      assert_matches %Query{
                       metrics: [:exit_rate],
                       dimensions: ["visit:exit_page"]
                     } = query
    end
  end

  on_ee do
    describe "query.consolidated_site_ids" do
      test "is set to nil when site is regular", %{site: site} do
        assert {:ok, %Query{consolidated_site_ids: nil}} =
                 Query.Builder.build(site, %ParsedParams{
                   metrics: [:visitors],
                   input_date_range: :all
                 })
      end

      test "is set to a list of site_ids when site is consolidated", %{site: site} do
        new_site(team: site.team)
        cv = new_consolidated_view(site.team)

        assert {:ok, %Query{consolidated_site_ids: consolidated_site_ids}} =
                 Query.Builder.build(cv, %ParsedParams{
                   metrics: [:visitors],
                   input_date_range: :all
                 })

        assert length(consolidated_site_ids) == 2
        assert site.id in consolidated_site_ids
      end
    end
  end
end
