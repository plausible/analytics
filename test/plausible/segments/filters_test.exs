defmodule Plausible.Segments.FiltersTest do
  use Plausible.DataCase, async: true
  alias Plausible.Segments
  alias Plausible.Stats.QueryError

  doctest Plausible.Segments.Filters, import: true

  setup [:create_user, :create_site]

  describe "preload_needed_segments/2" do
    test "returns an empty map without segment filters", %{site: site} do
      assert Segments.Filters.preload_needed_segments(site, [[:is, "visit:country", ["EE"]]]) ==
               {:ok, %{}}
    end

    test "returns the parsed filters of each segment by ID", %{site: site, user: user} do
      segment =
        insert(:segment,
          site: site,
          owner: user,
          type: :site,
          name: "Blog",
          segment_data: %{"filters" => [["is", "visit:entry_page", ["/blog"]]]}
        )

      assert Segments.Filters.preload_needed_segments(site, [[:is, "segment", [segment.id]]]) ==
               {:ok, %{segment.id => [[:is, "visit:entry_page", ["/blog"]]]}}
    end

    test "returns an error for a segment of another site", %{site: site, user: user} do
      other_site = new_site(owner: user)

      segment =
        insert(:segment, site: other_site, owner: user, type: :site, name: "Other site")

      assert {:error, %QueryError{code: :invalid_filters, message: message}} =
               Segments.Filters.preload_needed_segments(site, [[:is, "segment", [segment.id]]])

      assert message == "Invalid filters. Some segments don't exist or aren't accessible."
    end

    test "returns an error for a segment that does not exist", %{site: site} do
      assert {:error, %QueryError{code: :invalid_filters}} =
               Segments.Filters.preload_needed_segments(site, [[:is, "segment", [0]]])
    end

    test "returns an error for a segment with filters that do not parse", %{
      site: site,
      user: user
    } do
      segment =
        insert(:segment,
          site: site,
          owner: user,
          type: :site,
          name: "Broken",
          segment_data: %{"filters" => [["unknown_operator", "visit:entry_page", ["/blog"]]]}
        )

      assert {:error, %QueryError{code: :invalid_filters}} =
               Segments.Filters.preload_needed_segments(site, [[:is, "segment", [segment.id]]])
    end
  end

  describe "resolve_segments/2" do
    test "merges several top-level segments into the top-level filters" do
      entry_page_filter = [:is, "visit:entry_page", ["/home"]]
      country_filter = [:is, "visit:country", ["PL"]]
      goal_filter = [:is, "event:goal", ["Signup"]]

      assert Segments.Filters.resolve_segments(
               [entry_page_filter, [:is, "segment", [1]], [:is, "segment", [2]]],
               %{1 => [country_filter], 2 => [goal_filter]}
             ) == {:ok, [entry_page_filter, country_filter, goal_filter]}
    end

    test "replaces a filter with several segment IDs under an `:or` tree" do
      segment_1_filters = [[:contains, "event:goal", ["Singup"]], [:is, "visit:country", ["PL"]]]
      segment_2_filters = [[:contains, "event:goal", ["Sauna"]], [:is, "visit:country", ["EE"]]]

      assert Segments.Filters.resolve_segments(
               [[:is, "segment", [1, 2]]],
               %{1 => segment_1_filters, 2 => segment_2_filters}
             ) ==
               {:ok, [[:or, [[:and, segment_1_filters], [:and, segment_2_filters]]]]}
    end

    test "replaces a nested segment in place, without merging it into the top level" do
      segment_filters = [[:is, "visit:country", ["PL"]]]

      assert Segments.Filters.resolve_segments(
               [[:not, [:is, "segment", [1]]]],
               %{1 => segment_filters}
             ) == {:ok, [[:not, [:and, segment_filters]]]}
    end
  end

  describe "preload_and_resolve/2" do
    test "replaces a segment filter with the filters of the segment", %{site: site, user: user} do
      segment =
        insert(:segment,
          site: site,
          owner: user,
          type: :site,
          name: "Blog",
          segment_data: %{"filters" => [["is", "visit:entry_page", ["/blog"]]]}
        )

      country_filter = [:is, "visit:country", ["EE"]]

      assert Segments.Filters.preload_and_resolve(site, [
               country_filter,
               [:is, "segment", [segment.id]]
             ]) == {:ok, [country_filter, [:is, "visit:entry_page", ["/blog"]]]}
    end
  end
end
