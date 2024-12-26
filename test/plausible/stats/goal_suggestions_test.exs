defmodule Plausible.Stats.GoalSuggestionsTest do
  use Plausible.DataCase, async: true
  alias Plausible.Stats.GoalSuggestions

  describe "suggest_event_names/3" do
    setup [:create_user, :create_site]

    test "returns custom event goal suggestions including imported data, ordered by visitor count",
         %{site: site} do
      site_import = insert(:site_import, site: site)

      populate_stats(
        site,
        site_import.id,
        [
          build(:event, name: "Signup"),
          build(:event, name: "Signup"),
          build(:event, name: "Signup"),
          build(:event, name: "Signup"),
          build(:event, name: "Signup Newsletter"),
          build(:event, name: "Signup Newsletter"),
          build(:imported_custom_events, name: "Signup Newsletter", visitors: 3),
          build(:imported_custom_events, name: "Outbound Link: Click", visitors: 50)
        ] ++ build_list(10, :event, name: "Purchase", user_id: 123)
      )

      assert GoalSuggestions.suggest_event_names(site, "") == [
               "Outbound Link: Click",
               "Signup Newsletter",
               "Signup",
               "Purchase"
             ]
    end

    test "returns custom event goal suggestions with search input, including imported data",
         %{site: site} do
      site_import = insert(:site_import, site: site)

      populate_stats(site, site_import.id, [
        build(:event, name: "Some Signup"),
        build(:event, name: "Some Signup"),
        build(:event, name: "Some Signup"),
        build(:event, name: "sign"),
        build(:event, name: "A Sign"),
        build(:event, name: "A Sign"),
        build(:event, name: "Not Matching"),
        build(:imported_custom_events, name: "GA Signup", visitors: 4),
        build(:imported_custom_events, name: "Not Matching", visitors: 3)
      ])

      assert GoalSuggestions.suggest_event_names(site, "Sign") == [
               "GA Signup",
               "Some Signup",
               "A Sign",
               "sign"
             ]
    end

    test "ignores 'pageview' and 'pageleave' event names", %{site: site} do
      populate_stats(site, [
        build(:event, name: "Signup"),
        build(:pageview,
          user_id: 1,
          timestamp: NaiveDateTime.utc_now() |> NaiveDateTime.add(-1, :minute)
        ),
        build(:pageleave, user_id: 1, timestamp: NaiveDateTime.utc_now())
      ])

      assert GoalSuggestions.suggest_event_names(site, "") == ["Signup"]
    end

    test "ignores event names with either white space on either end or consisting only of whitespace",
         %{site: site} do
      site_import = insert(:site_import, site: site)

      populate_stats(site, site_import.id, [
        build(:event, name: "Signup"),
        build(:event, name: " Signup2"),
        build(:event, name: " Signup2 "),
        build(:event, name: "Signup2 "),
        build(:event, name: "    "),
        build(:imported_custom_events, name: "Auth", visitors: 3),
        build(:imported_custom_events, name: " Auth2", visitors: 3),
        build(:imported_custom_events, name: " Auth2 ", visitors: 3),
        build(:imported_custom_events, name: "Auth2 ", visitors: 3),
        build(:imported_custom_events, name: "            ", visitors: 3),
        build(:pageview)
      ])

      assert GoalSuggestions.suggest_event_names(site, "") == ["Auth", "Signup"]
    end

    test "can exclude goals from being suggested", %{site: site} do
      populate_stats(site, [build(:event, name: "Signup")])

      assert GoalSuggestions.suggest_event_names(site, "", exclude: ["Signup"]) == []
    end

    test "does not suggest event names longer than schema allows", %{site: site} do
      populate_stats(site, [build(:event, name: String.duplicate("A", 121))])

      assert GoalSuggestions.suggest_event_names(site, "") == []
    end
  end
end
