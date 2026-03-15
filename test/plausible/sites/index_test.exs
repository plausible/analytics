defmodule Plausible.Sites.IndexTest do
  use Plausible.DataCase, async: true

  alias Plausible.Sites.Index
  alias Plausible.Sites.Index.State

  describe "fetch_site_ids/2" do
    test "returns empty list when user has no sites" do
      user = new_user()
      _rogue_site = new_site()

      assert Index.fetch_site_ids(user) == []
    end

    test "returns IDs for owned sites on personal (non-setup) team" do
      user = new_user()
      site = new_site(owner: user)

      ids = Index.fetch_site_ids(user)
      assert site.id in ids
    end

    test "returns IDs for guest sites when no team set" do
      owner = new_user()
      user = new_user()
      site = new_site(owner: owner)
      add_guest(site, user: user, role: :editor)

      ids = Index.fetch_site_ids(user)
      assert site.id in ids
    end

    on_ee do
      test "does not include consolidated views" do
        user = new_user()
        {:ok, team} = Plausible.Teams.get_or_create(user)
        regular1 = new_site(team: team)
        regular2 = new_site(team: team)

        new_consolidated_view(team)

        team = Plausible.Teams.complete_setup(team)

        assert Index.fetch_site_ids(user, team: team) == [regular1.id, regular2.id]
      end
    end

    test "scopes to team when team is set and setup" do
      user = new_user()
      site1 = new_site(owner: user)
      other_user = new_user()
      site2 = new_site(owner: other_user)
      team2 = Plausible.Teams.complete_setup(site2.team)
      add_member(site2.team, user: user, role: :admin)

      ids = Index.fetch_site_ids(user, team: team2)
      assert site2.id in ids
      refute site1.id in ids
    end

    test "non-setup team: own sites and guest sites both included" do
      user = new_user()
      own_site = new_site(owner: user)
      other_owner = new_user()
      guest_site = new_site(owner: other_owner)
      add_guest(guest_site, user: user, role: :editor)

      personal_team = team_of(user)

      ids = Index.fetch_site_ids(user, team: personal_team)
      assert own_site.id in ids
      assert guest_site.id in ids
    end

    test "setup team: guest memberships on other sites are excluded" do
      user = new_user()
      guest_owner = new_user()
      guest_site = new_site(owner: guest_owner)
      add_guest(guest_site, user: user, role: :editor)

      team_owner = new_user()
      team_site = new_site(owner: team_owner)
      setup_team = Plausible.Teams.complete_setup(team_site.team)
      add_member(team_site.team, user: user, role: :admin)

      ids = Index.fetch_site_ids(user, team: setup_team)
      assert team_site.id in ids
      refute guest_site.id in ids
    end
  end

  describe "traffic_for_site_ids/1" do
    test "returns empty list when site_ids is empty" do
      assert Index.traffic_for_site_ids([]) == []
    end

    test "returns empty list and captures Sentry report when a batch query fails", %{
      test_pid: test_pid
    } do
      Plausible.Test.Support.Sentry.setup(test_pid)

      assert Index.traffic_for_site_ids([1, :force_the_batch_to_fail, 3]) == []

      assert [report] = Sentry.Test.pop_sentry_reports()
      assert report.message.formatted == "traffic_for_site_ids: batch query failed"
      assert report.extra.batch_size == 3
      assert report.extra.first_site_id == 1
      assert report.extra.last_site_id == 3
      assert is_binary(report.extra.error)
    end

    test "returns visitor counts for sites with events in 24h window" do
      user = new_user()
      site = new_site(owner: user)

      now = NaiveDateTime.utc_now()

      populate_stats(site, [
        build(:pageview, timestamp: NaiveDateTime.add(now, -1, :hour), user_id: 1),
        build(:pageview, timestamp: NaiveDateTime.add(now, -2, :hour), user_id: 2),
        build(:pageview, timestamp: NaiveDateTime.add(now, -2, :hour), user_id: 2)
      ])

      results = Index.traffic_for_site_ids([site.id])

      assert length(results) == 1
      [{returned_id, visitors}] = results
      assert returned_id == site.id
      assert visitors == 2
    end

    test "does not count engagement-only users as visitors" do
      user = new_user()
      site = new_site(owner: user)

      now = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)

      populate_stats(site, [
        build(:pageview, timestamp: now, user_id: 1),
        build(:pageview, timestamp: now, user_id: 2),
        build(:engagement, timestamp: now, user_id: 2, pathname: "/")
      ])

      results = Index.traffic_for_site_ids([site.id])
      [{_id, visitors}] = results
      assert visitors == 2
    end

    test "excludes events outside the time window" do
      user = new_user()
      site = new_site(owner: user)

      now = NaiveDateTime.utc_now()

      populate_stats(site, [
        build(:pageview, timestamp: NaiveDateTime.add(now, -25, :hour), user_id: 1)
      ])

      results = Index.traffic_for_site_ids([site.id])
      assert results == []
    end

    test "returns results for multiple sites" do
      user = new_user()
      site_a = new_site(owner: user)
      site_b = new_site(owner: user)

      now = NaiveDateTime.utc_now()

      populate_stats(site_a, [
        build(:pageview, timestamp: NaiveDateTime.add(now, -1, :hour), user_id: 1),
        build(:pageview, timestamp: NaiveDateTime.add(now, -1, :hour), user_id: 2)
      ])

      populate_stats(site_b, [
        build(:pageview, timestamp: NaiveDateTime.add(now, -1, :hour), user_id: 3)
      ])

      results = Index.traffic_for_site_ids([site_a.id, site_b.id])
      traffic_map = Map.new(results)

      assert Map.get(traffic_map, site_a.id) == 2
      assert Map.get(traffic_map, site_b.id) == 1
    end

    test "sites with no events in the window are omitted from results (callers default to 0)" do
      user = new_user()
      site = new_site(owner: user)

      results = Index.traffic_for_site_ids([site.id])

      # no matching rows, will be treated as 0
      assert results == []
    end
  end

  describe "build/2" do
    test "returns a State struct" do
      user = new_user()
      state = Index.build(user)

      assert %State{} = state
      assert state.user == user
      assert state.sort_by == :alnum
      assert state.sort_direction == :asc
    end

    test "ordered_ids is empty when user has no sites" do
      user = new_user()
      state = Index.build(user)

      assert state.ordered_ids == []
    end

    test "ordered_ids contains all visible site IDs" do
      user = new_user()
      site_a = new_site(owner: user, domain: "a.example.com")
      site_b = new_site(owner: user, domain: "b.example.com")

      state = Index.build(user)

      assert Enum.sort(state.ordered_ids) == Enum.sort([site_a.id, site_b.id])
    end

    test "ordered_ids includes sites with no traffic for traffic sort)" do
      user = new_user()
      _site = new_site(owner: user)

      state = Index.build(user, sort_by: :traffic)

      assert length(state.ordered_ids) == 1
    end

    test "alnum sort: ordered_ids ascending by domain" do
      user = new_user()
      site_z = new_site(owner: user, domain: "z.example.com")
      site_a = new_site(owner: user, domain: "a.example.com")

      state = Index.build(user, sort_by: :alnum, sort_direction: :asc)

      assert state.ordered_ids == [site_a.id, site_z.id]
    end

    test "alnum sort: ordered_ids descending by domain" do
      user = new_user()
      site_z = new_site(owner: user, domain: "z.example.com")
      site_a = new_site(owner: user, domain: "a.example.com")

      state = Index.build(user, sort_by: :alnum, sort_direction: :desc)

      assert state.ordered_ids == [site_z.id, site_a.id]
    end

    test "alnum sort: pinned sites come first regardless of domain" do
      user = new_user()
      site_z = new_site(owner: user, domain: "z.example.com")
      site_a = new_site(owner: user, domain: "a.example.com")

      {:ok, _} = Plausible.Sites.toggle_pin(user, site_z)

      state = Index.build(user, sort_by: :alnum, sort_direction: :asc)

      assert state.ordered_ids == [site_z.id, site_a.id]
    end

    test "traffic sort: ordered_ids descending by visitors" do
      user = new_user()
      site_low = new_site(owner: user)
      site_high = new_site(owner: user)

      now = NaiveDateTime.utc_now()

      populate_stats(site_high, [
        build(:pageview, timestamp: NaiveDateTime.add(now, -1, :hour), user_id: 1),
        build(:pageview, timestamp: NaiveDateTime.add(now, -1, :hour), user_id: 2)
      ])

      populate_stats(site_low, [
        build(:pageview, timestamp: NaiveDateTime.add(now, -1, :hour), user_id: 3)
      ])

      state = Index.build(user, sort_by: :traffic, sort_direction: :desc)

      assert state.ordered_ids == [site_high.id, site_low.id]
    end

    test "traffic sort: ordered_ids ascending by visitors" do
      user = new_user()
      site_low = new_site(owner: user)
      site_high = new_site(owner: user)

      now = NaiveDateTime.utc_now()

      populate_stats(site_high, [
        build(:pageview, timestamp: NaiveDateTime.add(now, -1, :hour), user_id: 1),
        build(:pageview, timestamp: NaiveDateTime.add(now, -1, :hour), user_id: 2)
      ])

      populate_stats(site_low, [
        build(:pageview, timestamp: NaiveDateTime.add(now, -1, :hour), user_id: 3)
      ])

      state = Index.build(user, sort_by: :traffic, sort_direction: :asc)

      assert state.ordered_ids == [site_low.id, site_high.id]
    end

    test "traffic sort: zero-traffic sites ordered last in :desc, first in :asc" do
      user = new_user()
      site_empty = new_site(owner: user)
      site_busy = new_site(owner: user)

      now = NaiveDateTime.utc_now()

      populate_stats(site_busy, [
        build(:pageview, timestamp: NaiveDateTime.add(now, -1, :hour), user_id: 1)
      ])

      state_desc = Index.build(user, sort_by: :traffic, sort_direction: :desc)
      assert state_desc.ordered_ids == [site_busy.id, site_empty.id]

      state_asc = Index.build(user, sort_by: :traffic, sort_direction: :asc)
      assert state_asc.ordered_ids == [site_empty.id, site_busy.id]
    end

    test "traffic sort: pinned sites come first regardless of traffic" do
      user = new_user()
      site_busy = new_site(owner: user)
      site_pinned = new_site(owner: user)

      now = NaiveDateTime.utc_now()

      populate_stats(site_busy, [
        build(:pageview, timestamp: NaiveDateTime.add(now, -1, :hour), user_id: 1),
        build(:pageview, timestamp: NaiveDateTime.add(now, -1, :hour), user_id: 2),
        build(:pageview, timestamp: NaiveDateTime.add(now, -1, :hour), user_id: 3)
      ])

      populate_stats(site_pinned, [
        build(:pageview, timestamp: NaiveDateTime.add(now, -1, :hour), user_id: 4)
      ])

      {:ok, _} = Plausible.Sites.toggle_pin(user, site_pinned)

      state = Index.build(user, sort_by: :traffic, sort_direction: :desc)

      assert hd(state.ordered_ids) == site_pinned.id
    end

    test "traffic map is empty for alnum sort" do
      user = new_user()
      _site = new_site(owner: user)

      state = Index.build(user, sort_by: :alnum)

      assert state.traffic == %{}
    end

    test "traffic map is populated for traffic sort" do
      user = new_user()
      site = new_site(owner: user)

      now = NaiveDateTime.utc_now()

      populate_stats(site, [
        build(:pageview, timestamp: NaiveDateTime.add(now, -1, :hour), user_id: 1)
      ])

      state = Index.build(user, sort_by: :traffic)

      assert is_map(state.traffic)
      assert Map.get(state.traffic, site.id) == 1
    end

    test "defaults to alnum/asc when no opts given" do
      user = new_user()
      state = Index.build(user)

      assert state.sort_by == :alnum
      assert state.sort_direction == :asc
    end

    test "stores team in opts map" do
      user = new_user()
      other_user = new_user()
      team_site = new_site(owner: other_user)
      team = Plausible.Teams.complete_setup(team_site.team)
      add_member(team_site.team, user: user, role: :admin)

      state = Index.build(user, team: team)

      assert state.opts == %{team: team}
    end

    test "filter_by_domain is respected at paginate time" do
      user = new_user()
      site_a = new_site(owner: user, domain: "alpha.example.com")
      _site_b = new_site(owner: user, domain: "beta.example.com")

      state = Index.build(user)

      assert length(state.ordered_ids) == 2

      page = Index.paginate(state, 1, 24, "alpha")
      assert page.entries == [site_a.id]
      assert page.total_entries == 1
    end

    test "scopes to setup team" do
      user = new_user()
      personal_site = new_site(owner: user)
      other_user = new_user()
      team_site = new_site(owner: other_user)
      team = Plausible.Teams.complete_setup(team_site.team)
      add_member(team_site.team, user: user, role: :admin)

      state = Index.build(user, team: team)

      assert team_site.id in state.ordered_ids
      refute personal_site.id in state.ordered_ids
    end

    test "revoked guest membership removes site from ordered_ids even when pinned" do
      owner = new_user()
      user = new_user()
      site = new_site(owner: owner, domain: "revoked.example.com")
      add_guest(site, user: user, role: :editor)
      {:ok, _} = Plausible.Sites.toggle_pin(user, site)

      state_before = Index.build(user)
      assert site.id in state_before.ordered_ids

      revoke_membership(site, user)

      state_after = Index.build(user)
      refute site.id in state_after.ordered_ids
    end

    test "alnum sort: multiple pinned sites ordered by pinned_at descending" do
      user = new_user()
      site_a = new_site(owner: user, domain: "a.example.com")
      site_b = new_site(owner: user, domain: "b.example.com")

      Plausible.Sites.set_option(user, site_a, :pinned_at, ~N[2024-01-01 10:00:00])
      Plausible.Sites.set_option(user, site_b, :pinned_at, ~N[2024-01-02 10:00:00])

      state = Index.build(user, sort_by: :alnum, sort_direction: :asc)

      # site_b was pinned more recently
      assert state.ordered_ids == [site_b.id, site_a.id]
    end
  end

  describe "paginate/3" do
    test "returns a Page of site IDs" do
      user = new_user()
      site = new_site(owner: user)

      state = Index.build(user)
      page = Index.paginate(state, 1, 24)

      assert %Index.Page{} = page
      assert page.entries == [site.id]
      assert page.total_entries == 1
      assert page.page_number == 1
      assert page.total_pages == 1
    end

    test "returns empty page when user has no sites" do
      user = new_user()
      state = Index.build(user)
      page = Index.paginate(state, 1, 24)

      assert page.entries == []
      assert page.total_entries == 0
      assert page.total_pages == 1
    end

    test "slices correct page window" do
      user = new_user()
      sites = for i <- 0..9, do: new_site(owner: user, domain: "slice-#{i}.example.com")

      state = Index.build(user, sort_by: :alnum, sort_direction: :asc)

      page1 = Index.paginate(state, 1, 3)
      page2 = Index.paginate(state, 2, 3)
      page3 = Index.paginate(state, 3, 3)
      page4 = Index.paginate(state, 4, 3)

      assert page1.total_entries == 10
      assert page1.total_pages == 4
      assert length(page1.entries) == 3
      assert length(page2.entries) == 3
      assert length(page3.entries) == 3
      assert length(page4.entries) == 1

      all_ids = page1.entries ++ page2.entries ++ page3.entries ++ page4.entries

      assert Enum.map(sites, & &1.id) == all_ids
    end

    test "preserves ordering from state" do
      user = new_user()
      site_z = new_site(owner: user, domain: "z.example.com")
      site_a = new_site(owner: user, domain: "a.example.com")

      state_asc = Index.build(user, sort_by: :alnum, sort_direction: :asc)
      page_asc = Index.paginate(state_asc, 1, 24)
      assert page_asc.entries == [site_a.id, site_z.id]

      state_desc = Index.build(user, sort_by: :alnum, sort_direction: :desc)
      page_desc = Index.paginate(state_desc, 1, 24)
      assert page_desc.entries == [site_z.id, site_a.id]
    end

    test "clamps page_number to total_pages when out of range" do
      user = new_user()
      _site = new_site(owner: user)

      state = Index.build(user)
      page = Index.paginate(state, 999, 24)

      assert page.page_number == 1
      assert length(page.entries) == 1
    end

    test "page_size larger than total_entries returns all entries on page 1" do
      user = new_user()
      site_a = new_site(owner: user, domain: "a.example.com")
      site_b = new_site(owner: user, domain: "b.example.com")

      state = Index.build(user, sort_by: :alnum, sort_direction: :asc)
      page = Index.paginate(state, 1, 100)

      assert page.total_pages == 1
      assert page.entries == [site_a.id, site_b.id]
    end

    test "accepts string page and page_size (e.g. from query-string params)" do
      user = new_user()
      for _ <- 1..5, do: new_site(owner: user)

      state = Index.build(user)

      page1 = Index.paginate(state, "1", "3")
      page2 = Index.paginate(state, "2", "3")

      assert page1.total_entries == 5
      assert page1.total_pages == 2
      assert length(page1.entries) == 3
      assert length(page2.entries) == 2
      assert MapSet.disjoint?(MapSet.new(page1.entries), MapSet.new(page2.entries))
    end

    test "invalid page falls back to page 1" do
      user = new_user()
      for _ <- 1..3, do: new_site(owner: user)

      state = Index.build(user)

      assert Index.paginate(state, "abc", 24).page_number == 1
      assert Index.paginate(state, "0", 24).page_number == 1
      assert Index.paginate(state, nil, 24).page_number == 1
    end

    test "page_size out of range falls back to default of 24" do
      user = new_user()
      for _ <- 1..5, do: new_site(owner: user)

      state = Index.build(user)

      assert Index.paginate(state, 1, "0").page_size == 24
      assert Index.paginate(state, 1, "101").page_size == 24
    end

    test "nil page and page_size fall back to defaults (page 1, page_size 24)" do
      user = new_user()
      for _ <- 1..5, do: new_site(owner: user)

      state = Index.build(user)
      page = Index.paginate(state, nil, nil)

      assert page.page_number == 1
      assert page.page_size == 24
    end
  end

  describe "refresh_pins/1" do
    test "returns a new State" do
      user = new_user()
      _site = new_site(owner: user)

      state = Index.build(user)
      new_state = Index.refresh_pins(state)

      assert %State{} = new_state
    end

    test "pinning a site moves it to the front" do
      user = new_user()
      site_z = new_site(owner: user, domain: "z.example.com")
      site_a = new_site(owner: user, domain: "a.example.com")

      state = Index.build(user, sort_by: :alnum, sort_direction: :asc)

      assert state.ordered_ids == [site_a.id, site_z.id]

      {:ok, _} = Plausible.Sites.toggle_pin(user, site_z)

      new_state = Index.refresh_pins(state)
      assert new_state.ordered_ids == [site_z.id, site_a.id]
    end

    test "unpinning a site moves it back into sort order" do
      user = new_user()
      site_z = new_site(owner: user, domain: "z.example.com")
      site_a = new_site(owner: user, domain: "a.example.com")

      {:ok, pref} = Plausible.Sites.toggle_pin(user, site_z)

      state = Index.build(user, sort_by: :alnum, sort_direction: :asc)
      assert hd(state.ordered_ids) == site_z.id

      site_z_pinned = %{site_z | pinned_at: pref.pinned_at}
      {:ok, _} = Plausible.Sites.toggle_pin(user, site_z_pinned)

      new_state = Index.refresh_pins(state)
      assert new_state.ordered_ids == [site_a.id, site_z.id]
    end

    test "preserves all other State fields" do
      user = new_user()
      _site = new_site(owner: user)
      opts = [sort_by: :alnum, sort_direction: :desc]

      state = Index.build(user, opts)
      new_state = Index.refresh_pins(state)

      assert new_state.user == state.user
      assert new_state.opts == state.opts
      assert new_state.sort_by == state.sort_by
      assert new_state.sort_direction == state.sort_direction
    end

    test "does not re-query ClickHouse (traffic preserved)" do
      user = new_user()
      site = new_site(owner: user)

      now = NaiveDateTime.utc_now()

      populate_stats(site, [
        build(:pageview, timestamp: NaiveDateTime.add(now, -1, :hour), user_id: 1)
      ])

      state = Index.build(user, sort_by: :traffic)
      traffic_before = state.traffic

      populate_stats(site, [
        build(:pageview, timestamp: NaiveDateTime.add(now, -1, :hour), user_id: 2),
        build(:pageview, timestamp: NaiveDateTime.add(now, -1, :hour), user_id: 3)
      ])

      new_state = Index.refresh_pins(state)
      assert new_state.traffic == traffic_before
    end

    test "traffic sort: pinning a site moves it to front, traffic order preserved for rest" do
      user = new_user()
      site_low = new_site(owner: user, domain: "low.example.com")
      site_mid = new_site(owner: user, domain: "mid.example.com")
      site_high = new_site(owner: user, domain: "high.example.com")

      now = NaiveDateTime.utc_now()

      populate_stats(site_high, [
        build(:pageview, timestamp: NaiveDateTime.add(now, -1, :hour), user_id: 1),
        build(:pageview, timestamp: NaiveDateTime.add(now, -1, :hour), user_id: 2),
        build(:pageview, timestamp: NaiveDateTime.add(now, -1, :hour), user_id: 3)
      ])

      populate_stats(site_mid, [
        build(:pageview, timestamp: NaiveDateTime.add(now, -1, :hour), user_id: 4),
        build(:pageview, timestamp: NaiveDateTime.add(now, -1, :hour), user_id: 5)
      ])

      populate_stats(site_low, [
        build(:pageview, timestamp: NaiveDateTime.add(now, -1, :hour), user_id: 6)
      ])

      state = Index.build(user, sort_by: :traffic, sort_direction: :desc)
      assert state.ordered_ids == [site_high.id, site_mid.id, site_low.id]

      {:ok, _} = Plausible.Sites.toggle_pin(user, site_low)

      new_state = Index.refresh_pins(state)

      # site_low is pinned, moves to front
      assert new_state.ordered_ids == [site_low.id, site_high.id, site_mid.id]
    end
  end

  describe "sort/2" do
    test "alnum asc -> desc flips order, no traffic map, no extra queries" do
      user = new_user()
      site_z = new_site(owner: user, domain: "z.example.com")
      site_a = new_site(owner: user, domain: "a.example.com")

      state = Index.build(user, sort_by: :alnum, sort_direction: :asc)
      assert state.ordered_ids == [site_a.id, site_z.id]

      new_state = Index.sort(state, sort_direction: :desc)
      assert new_state.ordered_ids == [site_z.id, site_a.id]
      assert new_state.sort_by == :alnum
      assert new_state.sort_direction == :desc
      assert new_state.traffic == %{}
    end

    test "alnum -> traffic: fetches traffic from ClickHouse and re-sorts" do
      user = new_user()
      site_low = new_site(owner: user)
      site_high = new_site(owner: user)

      now = NaiveDateTime.utc_now()

      populate_stats(site_high, [
        build(:pageview, timestamp: NaiveDateTime.add(now, -1, :hour), user_id: 1),
        build(:pageview, timestamp: NaiveDateTime.add(now, -1, :hour), user_id: 2)
      ])

      populate_stats(site_low, [
        build(:pageview, timestamp: NaiveDateTime.add(now, -1, :hour), user_id: 3)
      ])

      state = Index.build(user, sort_by: :alnum, sort_direction: :asc)
      assert state.traffic == %{}

      new_state = Index.sort(state, sort_by: :traffic, sort_direction: :desc)

      assert new_state.sort_by == :traffic
      assert new_state.sort_direction == :desc
      assert map_size(new_state.traffic) == 2
      assert new_state.ordered_ids == [site_high.id, site_low.id]
    end

    test "traffic -> alnum: clears traffic map, re-sorts by domain without querying ClickHouse" do
      user = new_user()
      site_z = new_site(owner: user, domain: "z.example.com")
      site_a = new_site(owner: user, domain: "a.example.com")

      now = NaiveDateTime.utc_now()

      populate_stats(site_z, [
        build(:pageview, timestamp: NaiveDateTime.add(now, -1, :hour), user_id: 1)
      ])

      state = Index.build(user, sort_by: :traffic, sort_direction: :desc)
      assert map_size(state.traffic) == 1

      new_state = Index.sort(state, sort_by: :alnum, sort_direction: :asc)

      assert new_state.sort_by == :alnum
      assert new_state.sort_direction == :asc
      assert new_state.traffic == %{}
      assert new_state.ordered_ids == [site_a.id, site_z.id]
    end

    test "traffic desc -> traffic asc: reuses existing traffic map, no CH query" do
      user = new_user()
      site_low = new_site(owner: user, domain: "low.example.com")
      site_high = new_site(owner: user, domain: "high.example.com")

      now = NaiveDateTime.utc_now()

      populate_stats(site_high, [
        build(:pageview, timestamp: NaiveDateTime.add(now, -1, :hour), user_id: 1),
        build(:pageview, timestamp: NaiveDateTime.add(now, -1, :hour), user_id: 2)
      ])

      populate_stats(site_low, [
        build(:pageview, timestamp: NaiveDateTime.add(now, -1, :hour), user_id: 3)
      ])

      state = Index.build(user, sort_by: :traffic, sort_direction: :desc)
      assert state.ordered_ids == [site_high.id, site_low.id]
      original_traffic = state.traffic

      # more events, not re-queried
      populate_stats(site_low, [
        build(:pageview, timestamp: NaiveDateTime.add(now, -1, :hour), user_id: 4),
        build(:pageview, timestamp: NaiveDateTime.add(now, -1, :hour), user_id: 5),
        build(:pageview, timestamp: NaiveDateTime.add(now, -1, :hour), user_id: 6)
      ])

      new_state = Index.sort(state, sort_direction: :asc)

      assert new_state.sort_direction == :asc
      assert new_state.traffic == original_traffic
      assert new_state.ordered_ids == [site_low.id, site_high.id]
    end

    test "preserves user, pins, and unrelated opts" do
      user = new_user()
      site = new_site(owner: user)

      {:ok, _} = Plausible.Sites.toggle_pin(user, site)

      state = Index.build(user, sort_by: :alnum, sort_direction: :asc, filter_by_domain: "")
      new_state = Index.sort(state, sort_direction: :desc)
      assert new_state.user == state.user
      assert new_state.pins == state.pins
      assert new_state.ordered_ids == [site.id]
    end
  end
end
