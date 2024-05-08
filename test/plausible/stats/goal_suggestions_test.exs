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
               {"Outbound Link: Click", "Outbound Link: Click"},
               {"Signup Newsletter", "Signup Newsletter"},
               {"Signup", "Signup"},
               {"Purchase", "Purchase"}
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
               {"GA Signup", "GA Signup"},
               {"Some Signup", "Some Signup"},
               {"A Sign", "A Sign"},
               {"sign", "sign"}
             ]
    end

    test "ignores the 'pageview' event name", %{site: site} do
      populate_stats(site, [
        build(:event, name: "Signup"),
        build(:pageview)
      ])

      assert GoalSuggestions.suggest_event_names(site, "") == [
               {"Signup", "Signup"}
             ]
    end

    test "can exclude goals from being suggested", %{site: site} do
      populate_stats(site, [build(:event, name: "Signup")])

      assert GoalSuggestions.suggest_event_names(site, "", exclude: ["Signup"]) == []
    end
  end
end
