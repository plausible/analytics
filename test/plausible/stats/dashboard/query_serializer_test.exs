defmodule Plausible.Stats.Dashboard.QuerySerializerTest do
  use Plausible.DataCase
  import Plausible.Stats.Dashboard.{QueryParser, QuerySerializer}
  alias Plausible.Stats.ParsedQueryParams

  @default_include default_include()

  describe "parse -> serialize is a reversible transformation" do
    for query_string <- ["period=month", "date=2021-07-07&f=is,browser,Chrome,Firefox&period=day"] do
      test "with query string being '#{query_string}'" do
        {:ok, parsed} = parse(unquote(query_string), build(:site), %{})
        assert serialize(parsed) == unquote(query_string)
      end
    end

    test "but alphabetical ordering by key is enforced" do
      {:ok, parsed} = parse("period=day&date=2021-07-07", build(:site), %{})
      assert serialize(parsed) == "date=2021-07-07&period=day"
    end

    test "but redundant values get removed" do
      {:ok, parsed} = parse("period=all&with_imported=true", build(:site), %{})
      assert serialize(parsed) == "period=all"
    end

    test "but leading ? gets removed" do
      {:ok, parsed} = parse("?period=day", build(:site), %{})
      assert serialize(parsed) == "period=day"
    end
  end

  describe "input_date_range -> period (+ from, to)" do
    for input_date_range <- [:realtime, :day, :month, :year, :all] do
      test "serializes #{input_date_range} input_date_range" do
        params = %ParsedQueryParams{
          input_date_range: unquote(input_date_range),
          include: @default_include
        }

        assert serialize(params) == "period=#{Atom.to_string(unquote(input_date_range))}"
      end
    end

    for i <- [7, 28, 30, 91] do
      test "serializes {:last_n_days, #{i}} input_date_range" do
        params = %ParsedQueryParams{
          input_date_range: {:last_n_days, unquote(i)},
          include: @default_include
        }

        assert serialize(params) == "period=#{unquote(i)}d"
      end
    end

    for i <- [6, 12] do
      test "serializes {:last_n_months, #{i}} input_date_range" do
        params = %ParsedQueryParams{
          input_date_range: {:last_n_months, unquote(i)},
          include: @default_include
        }

        assert serialize(params) == "period=#{unquote(i)}mo"
      end
    end

    test "serlializes custom input_date_range" do
      params = %ParsedQueryParams{
        input_date_range: {:date_range, ~D[2021-01-01], ~D[2021-03-05]},
        include: @default_include
      }

      assert serialize(params) == "from=2021-01-01&period=custom&to=2021-03-05"
    end
  end

  describe "relative_date -> date" do
    test "serializes a date struct into iso8601" do
      params = %ParsedQueryParams{relative_date: ~D[2021-05-05], include: @default_include}
      assert serialize(params) == "date=2021-05-05"
    end
  end

  describe "include.imports -> with_imported" do
    test "false -> false" do
      params = %ParsedQueryParams{include: %{@default_include | imports: false}}
      assert serialize(params) == "with_imported=false"
    end
  end

  describe "include.compare -> comparison" do
    for mode <- [:previous_period, :year_over_year] do
      test "serializes #{mode} mode" do
        params = %ParsedQueryParams{include: %{@default_include | compare: unquote(mode)}}
        assert serialize(params) == "comparison=#{unquote(mode)}"
      end
    end

    test "serializes custom comparison range" do
      params = %ParsedQueryParams{
        include: %{@default_include | compare: {:date_range, ~D[2021-01-01], ~D[2021-04-30]}}
      }

      assert serialize(params) ==
               "compare_from=2021-01-01&compare_to=2021-04-30&comparison=custom"
    end
  end

  describe "include.compare_match_day_of_week -> match_day_of_week" do
    test "false -> false" do
      params = %ParsedQueryParams{include: %{@default_include | compare_match_day_of_week: false}}
      assert serialize(params) == "match_day_of_week=false"
    end
  end

  describe "filters" do
    test "serializes multiple is filters" do
      serialized =
        serialize(%ParsedQueryParams{
          filters: [
            [:is, "visit:exit_page", ["/:dashboard"]],
            [:is, "visit:source", ["Bing"]],
            [:is, "event:props:theme", ["system"]]
          ],
          include: @default_include
        })

      assert serialized == "f=is,exit_page,/:dashboard&f=is,source,Bing&f=is,props:theme,system"
    end

    test "serializes filters with integer clauses" do
      serialized =
        serialize(%ParsedQueryParams{
          filters: [
            [:is, "segment", [123, 456, 789]],
            [:is, "visit:city", [2_950_159]]
          ],
          include: @default_include
        })

      assert serialized == "f=is,segment,123,456,789&f=is,city,2950159&l=2950159,Berlin"
    end

    test "serializes empty filters" do
      serialized = serialize(%ParsedQueryParams{filters: [], include: @default_include}, [])
      assert serialized == ""
    end
  end

  describe "labels" do
    test "adds location labels" do
      serialized =
        serialize(%ParsedQueryParams{
          filters: [
            [:is, "visit:country", ["EE"]],
            [:is, "visit:region", ["EE-79"]],
            [:is, "visit:city", [588_335]]
          ],
          include: @default_include
        })

      assert serialized ==
               "f=is,country,EE&f=is,region,EE-79&f=is,city,588335&l=EE,Estonia&l=EE-79,Tartumaa&l=588335,Tartu"
    end

    test "adds segment label" do
      user = new_user()
      site = new_site(owner: user)

      segment =
        insert(:segment,
          type: :personal,
          owner: user,
          site: site,
          name: "personal segment"
        )

      serialized =
        serialize(
          %ParsedQueryParams{
            filters: [[:is, "segment", [segment.id]]],
            include: @default_include
          },
          [segment]
        )

      assert serialized ==
               "f=is,segment,#{segment.id}&l=#{segment.id},#{segment.name}"
    end

    test "skips location labels when not found" do
      serialized =
        serialize(%ParsedQueryParams{
          filters: [
            [:is, "visit:country", ["XX"]],
            [:is, "visit:region", ["XX-00"]],
            [:is, "visit:city", [999_999_999]]
          ],
          include: @default_include
        })

      assert serialized == "f=is,country,XX&f=is,region,XX-00&f=is,city,999999999"
    end

    test "skips segment label when not found" do
      serialized =
        serialize(%ParsedQueryParams{
          filters: [[:is, "segment", [1]]],
          include: @default_include
        })

      assert serialized == "f=is,segment,1"
    end
  end
end
