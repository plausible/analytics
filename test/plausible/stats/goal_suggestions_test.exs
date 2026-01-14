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

    test "ignores 'pageview' and 'engagement' event names", %{site: site} do
      populate_stats(site, [
        build(:event, name: "Signup"),
        build(:pageview,
          user_id: 1,
          timestamp: NaiveDateTime.utc_now() |> NaiveDateTime.add(-1, :minute)
        ),
        build(:engagement, user_id: 1, timestamp: NaiveDateTime.utc_now())
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

  describe "suggest_custom_property_names/3" do
    setup [:create_user, :create_site]

    test "returns custom property names from the last 30 days, ordered by usage count", %{
      site: site
    } do
      populate_stats(site, [
        build(:event,
          name: "Purchase",
          "meta.key": ["amount", "plan"],
          "meta.value": ["100", "business"],
          timestamp: NaiveDateTime.utc_now() |> NaiveDateTime.shift(day: -1)
        ),
        build(:event,
          name: "Purchase",
          "meta.key": ["plan"],
          "meta.value": ["enterprise"],
          timestamp: NaiveDateTime.utc_now() |> NaiveDateTime.shift(day: -5)
        ),
        build(:event,
          name: "Signup",
          "meta.key": ["plan", "referrer"],
          "meta.value": ["starter", "friend"],
          timestamp: NaiveDateTime.utc_now() |> NaiveDateTime.shift(day: -10)
        ),
        build(:event,
          name: "Click",
          "meta.key": ["button_id"],
          "meta.value": ["submit-btn"],
          timestamp: NaiveDateTime.utc_now() |> NaiveDateTime.shift(day: -20)
        )
      ])

      # "plan" appears 3 times, "amount" 1 time, "referrer" 1 time, "button_id" 1 time
      suggestions = GoalSuggestions.suggest_custom_property_names(site, "")
      assert "plan" == hd(suggestions)
      assert length(suggestions) == 4
      assert "plan" in suggestions
      assert "amount" in suggestions
      assert "referrer" in suggestions
      assert "button_id" in suggestions
    end

    test "filters property names by search input", %{site: site} do
      populate_stats(site, [
        build(:event,
          name: "Purchase",
          "meta.key": ["plan_type", "payment_method", "amount"],
          "meta.value": ["business", "credit_card", "100"],
          timestamp: NaiveDateTime.utc_now() |> NaiveDateTime.shift(day: -1)
        ),
        build(:event,
          name: "Signup",
          "meta.key": ["referrer", "plan_name"],
          "meta.value": ["google", "starter"],
          timestamp: NaiveDateTime.utc_now() |> NaiveDateTime.shift(day: -2)
        )
      ])

      suggestions = GoalSuggestions.suggest_custom_property_names(site, "plan")
      assert length(suggestions) == 2
      assert "plan_type" in suggestions
      assert "plan_name" in suggestions
      refute "amount" in suggestions
      refute "referrer" in suggestions
    end

    test "excludes events older than 30 days", %{site: site} do
      populate_stats(site, [
        build(:event,
          name: "Purchase",
          "meta.key": ["recent_prop"],
          "meta.value": ["value1"],
          timestamp: NaiveDateTime.utc_now() |> NaiveDateTime.shift(day: -29)
        ),
        build(:event,
          name: "Purchase",
          "meta.key": ["old_prop"],
          "meta.value": ["value2"],
          timestamp: NaiveDateTime.utc_now() |> NaiveDateTime.shift(day: -31)
        )
      ])

      suggestions = GoalSuggestions.suggest_custom_property_names(site, "")
      assert "recent_prop" in suggestions
      refute "old_prop" in suggestions

      suggestions = GoalSuggestions.suggest_custom_property_names(site, "prop")
      assert "recent_prop" in suggestions
      refute "old_prop" in suggestions
    end

    test "returns empty list when no custom properties exist", %{site: site} do
      populate_stats(site, [
        build(:event, name: "Purchase", timestamp: NaiveDateTime.utc_now())
      ])

      assert GoalSuggestions.suggest_custom_property_names(site, "") == []
    end

    test "handles nil search input", %{site: site} do
      populate_stats(site, [
        build(:event,
          name: "Purchase",
          "meta.key": ["plan"],
          "meta.value": ["business"],
          timestamp: NaiveDateTime.utc_now()
        )
      ])

      suggestions = GoalSuggestions.suggest_custom_property_names(site, nil)
      assert "plan" in suggestions
    end

    test "includes allowed_prop_names from site configuration when no event data exists", %{
      site: site
    } do
      site =
        site
        |> Ecto.Changeset.change(allowed_event_props: ["prop_a", "prop_b", "prop_c"])
        |> Repo.update!()

      suggestions = GoalSuggestions.suggest_custom_property_names(site, "")

      assert suggestions == ["prop_a", "prop_b", "prop_c"]
    end

    test "combines event_prop_names and allowed_prop_names, prioritizing event usage", %{
      site: site
    } do
      site =
        site
        |> Ecto.Changeset.change(
          allowed_event_props: ["allowed_prop", "shared_prop", "another_allowed"]
        )
        |> Repo.update!()

      populate_stats(site, [
        build(:event,
          name: "Purchase",
          "meta.key": ["event_prop"],
          "meta.value": ["value1"],
          timestamp: NaiveDateTime.utc_now() |> NaiveDateTime.shift(day: -1)
        ),
        build(:event,
          name: "Purchase",
          "meta.key": ["event_prop"],
          "meta.value": ["value2"],
          timestamp: NaiveDateTime.utc_now() |> NaiveDateTime.shift(day: -2)
        ),
        build(:event,
          name: "Signup",
          "meta.key": ["shared_prop"],
          "meta.value": ["value3"],
          timestamp: NaiveDateTime.utc_now() |> NaiveDateTime.shift(day: -3)
        )
      ])

      suggestions = GoalSuggestions.suggest_custom_property_names(site, "")

      assert suggestions == ["event_prop", "shared_prop", "allowed_prop", "another_allowed"]
    end

    test "filters allowed_prop_names by search input (case-insensitive)", %{
      site: site
    } do
      site =
        site
        |> Ecto.Changeset.change(
          allowed_event_props: ["plan_type", "user_plan", "payment_method", "amount"]
        )
        |> Repo.update!()

      suggestions = GoalSuggestions.suggest_custom_property_names(site, "plan")

      assert suggestions == ["plan_type", "user_plan"]
    end

    test "filters both event_prop_names and allowed_prop_names by search input", %{site: site} do
      site =
        site
        |> Ecto.Changeset.change(allowed_event_props: ["plan_type", "user_plan", "amount"])
        |> Repo.update!()

      populate_stats(site, [
        build(:event,
          name: "Purchase",
          "meta.key": ["plan_name", "payment_method"],
          "meta.value": ["business", "credit_card"],
          timestamp: NaiveDateTime.utc_now() |> NaiveDateTime.shift(day: -1)
        )
      ])

      suggestions = GoalSuggestions.suggest_custom_property_names(site, "plan")

      assert suggestions == ["plan_name", "plan_type", "user_plan"]
    end

    test "handles case-insensitive search matching for allowed_prop_names", %{site: site} do
      site =
        site
        |> Ecto.Changeset.change(allowed_event_props: ["UserPlan", "PLAN_TYPE", "Payment_Method"])
        |> Repo.update!()

      suggestions = GoalSuggestions.suggest_custom_property_names(site, "plan")

      assert suggestions == ["PLAN_TYPE", "UserPlan"]
    end

    test "deduplicates when property exists in both event_prop_names and allowed_prop_names", %{
      site: site
    } do
      site =
        site
        |> Ecto.Changeset.change(allowed_event_props: ["plan", "amount", "referrer"])
        |> Repo.update!()

      populate_stats(site, [
        build(:event,
          name: "Purchase",
          "meta.key": ["plan", "category"],
          "meta.value": ["business", "software"],
          timestamp: NaiveDateTime.utc_now() |> NaiveDateTime.shift(day: -1)
        ),
        build(:event,
          name: "Purchase",
          "meta.key": ["plan"],
          "meta.value": ["enterprise"],
          timestamp: NaiveDateTime.utc_now() |> NaiveDateTime.shift(day: -2)
        )
      ])

      suggestions = GoalSuggestions.suggest_custom_property_names(site, "")

      # plan appears only once
      assert suggestions == ["plan", "category", "amount", "referrer"]
    end

    test "handles empty allowed_event_props gracefully", %{site: site} do
      site =
        site
        |> Ecto.Changeset.change(allowed_event_props: [])
        |> Repo.update!()

      populate_stats(site, [
        build(:event,
          name: "Purchase",
          "meta.key": ["plan"],
          "meta.value": ["business"],
          timestamp: NaiveDateTime.utc_now()
        )
      ])

      suggestions = GoalSuggestions.suggest_custom_property_names(site, "")
      assert suggestions == ["plan"]
    end

    test "handles nil allowed_event_props gracefully", %{site: site} do
      site =
        site
        |> Ecto.Changeset.change(allowed_event_props: nil)
        |> Repo.update!()

      populate_stats(site, [
        build(:event,
          name: "Purchase",
          "meta.key": ["plan"],
          "meta.value": ["business"],
          timestamp: NaiveDateTime.utc_now()
        )
      ])

      suggestions = GoalSuggestions.suggest_custom_property_names(site, "")
      assert suggestions == ["plan"]
    end
  end

  describe "suggest_custom_property_values/3" do
    setup [:create_user, :create_site]

    test "returns custom property values for a given key from the last 30 days", %{site: site} do
      populate_stats(site, [
        build(:event,
          name: "Purchase",
          "meta.key": ["plan"],
          "meta.value": ["business"],
          timestamp: NaiveDateTime.utc_now() |> NaiveDateTime.shift(day: -1)
        ),
        build(:event,
          name: "Purchase",
          "meta.key": ["plan"],
          "meta.value": ["business"],
          timestamp: NaiveDateTime.utc_now() |> NaiveDateTime.shift(day: -2)
        ),
        build(:event,
          name: "Purchase",
          "meta.key": ["plan"],
          "meta.value": ["enterprise"],
          timestamp: NaiveDateTime.utc_now() |> NaiveDateTime.shift(day: -3)
        ),
        build(:event,
          name: "Signup",
          "meta.key": ["plan"],
          "meta.value": ["starter"],
          timestamp: NaiveDateTime.utc_now() |> NaiveDateTime.shift(day: -5)
        )
      ])

      suggestions = GoalSuggestions.suggest_custom_property_values(site, "plan", "")

      assert hd(suggestions) == "business"
      assert length(suggestions) == 3
      assert "business" in suggestions
      assert "enterprise" in suggestions
      assert "starter" in suggestions
    end

    test "filters property values by search input", %{site: site} do
      populate_stats(site, [
        build(:event,
          name: "Purchase",
          "meta.key": ["plan"],
          "meta.value": ["business_monthly"],
          timestamp: NaiveDateTime.utc_now() |> NaiveDateTime.shift(day: -1)
        ),
        build(:event,
          name: "Purchase",
          "meta.key": ["plan"],
          "meta.value": ["business_yearly"],
          timestamp: NaiveDateTime.utc_now() |> NaiveDateTime.shift(day: -2)
        ),
        build(:event,
          name: "Purchase",
          "meta.key": ["plan"],
          "meta.value": ["starter"],
          timestamp: NaiveDateTime.utc_now() |> NaiveDateTime.shift(day: -3)
        )
      ])

      suggestions = GoalSuggestions.suggest_custom_property_values(site, "plan", "business")
      assert length(suggestions) == 2
      assert "business_monthly" in suggestions
      assert "business_yearly" in suggestions
      refute "starter" in suggestions
    end

    test "excludes events older than 30 days", %{site: site} do
      populate_stats(site, [
        build(:event,
          name: "Purchase",
          "meta.key": ["plan"],
          "meta.value": ["recent_plan"],
          timestamp: NaiveDateTime.utc_now() |> NaiveDateTime.shift(day: -29)
        ),
        build(:event,
          name: "Purchase",
          "meta.key": ["plan"],
          "meta.value": ["old_plan"],
          timestamp: NaiveDateTime.utc_now() |> NaiveDateTime.shift(day: -31)
        )
      ])

      suggestions = GoalSuggestions.suggest_custom_property_values(site, "plan", "")
      assert "recent_plan" in suggestions
      refute "old_plan" in suggestions
    end

    test "handles nil search input", %{site: site} do
      populate_stats(site, [
        build(:event,
          name: "Purchase",
          "meta.key": ["plan"],
          "meta.value": ["business"],
          timestamp: NaiveDateTime.utc_now()
        )
      ])

      suggestions = GoalSuggestions.suggest_custom_property_values(site, "plan", nil)
      assert "business" in suggestions
    end

    test "orders values by count", %{site: site} do
      populate_stats(site, [
        build(:event,
          name: "Purchase",
          "meta.key": ["plan"],
          "meta.value": ["starter"],
          timestamp: NaiveDateTime.utc_now()
        ),
        build(:event,
          name: "Purchase",
          "meta.key": ["plan"],
          "meta.value": ["business"],
          timestamp: NaiveDateTime.utc_now()
        ),
        build(:event,
          name: "Purchase",
          "meta.key": ["plan"],
          "meta.value": ["business"],
          timestamp: NaiveDateTime.utc_now()
        ),
        build(:event,
          name: "Purchase",
          "meta.key": ["plan"],
          "meta.value": ["business"],
          timestamp: NaiveDateTime.utc_now()
        )
      ])

      assert ["business", "starter"] =
               GoalSuggestions.suggest_custom_property_values(site, "plan", "")
    end
  end
end
