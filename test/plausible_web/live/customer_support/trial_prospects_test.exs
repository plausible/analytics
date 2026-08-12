defmodule PlausibleWeb.Live.CustomerSupport.TrialProspectsTest do
  use PlausibleWeb.ConnCase, async: false
  @moduletag :ee_only

  on_ee do
    import Phoenix.LiveViewTest

    alias Plausible.Repo
    alias Plausible.CustomerSupport.TrialProspect

    defp open_prospects(qs \\ []) do
      Routes.customer_support_trial_prospects_path(PlausibleWeb.Endpoint, :index, qs)
    end

    setup [:create_user, :log_in]

    setup %{user: user} do
      patch_env(:super_admin_user_ids, [user.id])
    end

    defp prospect(team, attrs) do
      defaults = %{
        team_id: team.id,
        estimated_monthly: 50_000,
        observed_days: 10,
        first_data_day: ~D[2026-06-01],
        kind: :starter,
        forced_by: [],
        pageview_limit: 100_000,
        over_top_tier: false,
        estimated_mrr: 19,
        computed_at: ~U[2026-06-20 00:00:00Z]
      }

      Repo.insert!(struct!(TrialProspect, Map.merge(defaults, Map.new(attrs))))
    end

    test "renders trials ranked by MRR potential by default", %{conn: conn} do
      small = insert(:team, name: "Small Co")
      big = insert(:team, name: "Big Co")

      prospect(small, estimated_mrr: 19, kind: :starter)

      prospect(big,
        estimated_mrr: 339,
        kind: :business,
        forced_by: ["funnels", "team_member_limit"]
      )

      {:ok, _lv, html} = live(conn, open_prospects())
      text = text(html)

      assert text =~ "Trial prospects"
      assert text =~ "Feature tier"
      assert text =~ "Forced by"
      assert text =~ "Big Co"
      assert text =~ "Small Co"
      assert text =~ "€339/mo"

      # forced_by gates are labelled in the "Forced by" column
      assert text =~ "Funnels and user journeys"
      assert text =~ "Team members"

      # Big Co (higher MRR) is listed first
      assert text_of_element(html, "tbody tr:first-child") =~ "Big Co"
    end

    test "labels every forced_by gate in the Forced by column", %{conn: conn} do
      team = insert(:team, name: "Everything Co")

      gates = [
        {"site_limit", "Site limit"},
        {"team_member_limit", "Team members"},
        {"stats_api", "Stats API"},
        {"props", "Custom Properties"},
        {"revenue_goals", "Revenue Goals"},
        {"shared_links", "Shared Links"},
        {"site_segments", "Shared Segments"},
        {"site_annotations", "Shared Annotations"},
        {"funnels", "Funnels and user journeys"}
      ]

      prospect(team,
        estimated_mrr: 339,
        kind: :business,
        forced_by: Enum.map(gates, &elem(&1, 0))
      )

      {:ok, _lv, html} = live(conn, open_prospects())
      text = text(html)

      for {_gate, label} <- gates do
        assert text =~ label
      end
    end

    test "over-top-tier prospects sort above concrete MRR values", %{conn: conn} do
      enterprise = insert(:team, name: "Enterprise Co")
      business = insert(:team, name: "Business Co")

      prospect(business, estimated_mrr: 339, kind: :business, over_top_tier: false)

      prospect(enterprise,
        estimated_mrr: nil,
        kind: :business,
        over_top_tier: true,
        pageview_limit: nil
      )

      {:ok, _lv, html} = live(conn, open_prospects())

      assert text(html) =~ "Custom / Enterprise"
      assert text_of_element(html, "tbody tr:first-child") =~ "Enterprise Co"
    end

    test "can re-order by trial start date", %{conn: conn} do
      older = insert(:team, name: "Older Co", inserted_at: ~N[2026-01-01 00:00:00])
      newer = insert(:team, name: "Newer Co", inserted_at: ~N[2026-06-01 00:00:00])

      prospect(older, estimated_mrr: 9)
      prospect(newer, estimated_mrr: 339)

      # ascending: oldest trial start first
      {:ok, _lv, html} =
        live(conn, open_prospects(sort_by: "trial_start", sort_direction: "asc"))

      assert text_of_element(html, "tbody tr:first-child") =~ "Older Co"
    end

    test "excludes rows left behind for teams no longer on a trial", %{conn: conn} do
      live_team = insert(:team, name: "Live Co")
      prospect(live_team, estimated_mrr: 19)

      long_expired =
        insert(:team, name: "Long Expired Co", trial_expiry_date: Date.add(Date.utc_today(), -90))

      prospect(long_expired, estimated_mrr: 999)

      converted = insert(:team, name: "Converted Co")
      insert(:subscription, team: converted)
      prospect(converted, estimated_mrr: 999)

      {:ok, _lv, html} = live(conn, open_prospects())
      text = text(html)

      assert text =~ "Live Co"
      assert text =~ "1 prospects"
      refute text =~ "Long Expired Co"
      refute text =~ "Converted Co"
    end

    test "renders the owner email alongside the team", %{conn: conn} do
      team = new_user(email: "owner@example.com", team: [name: "Owned Co"]) |> team_of()
      prospect(team, estimated_mrr: 99)

      {:ok, _lv, html} = live(conn, open_prospects())

      assert text_of_element(html, "tbody tr:first-child") =~ "owner@example.com"
    end

    test "links each row to the team CS page", %{conn: conn} do
      team = insert(:team, name: "Linked Co")
      prospect(team, estimated_mrr: 99)

      {:ok, lv, _html} = live(conn, open_prospects())

      assert lv
             |> element(
               ~s|a[href="#{Routes.customer_support_team_path(PlausibleWeb.Endpoint, :show, team.id)}"]|
             )
             |> has_element?()
    end
  end
end
