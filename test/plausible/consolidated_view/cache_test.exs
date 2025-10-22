defmodule Plausible.CondolidatedView.CacheTest do
  use Plausible.DataCase, async: true
  use Plausible.Teams.Test

  on_ee do
    alias Plausible.ConsolidatedView
    alias Plausible.ConsolidatedView.Cache

    test "refresh_all stores site_ids per consolidated view id", %{test: test} do
      {owner1, owner2} = {new_user(), new_user()}
      {s1, s2} = {new_site(owner: owner1), new_site(owner: owner1)}
      team1 = team_of(owner1)

      {s3, s4, s5} = {new_site(owner: owner2), new_site(owner: owner2), new_site(owner: owner2)}
      team2 = team_of(owner2)

      consolidated_view1 = new_consolidated_view(team1)
      consolidated_view2 = new_consolidated_view(team2)

      start_test_cache(test)

      :ok = Cache.refresh_all(cache_name: test)

      assert Cache.size(test) == 2
      assert site_ids1 = Cache.get(consolidated_view1.domain, cache_name: test, force?: true)
      assert site_ids2 = Cache.get(consolidated_view2.domain, cache_name: test, force?: true)

      assert s1.id in site_ids1
      assert s2.id in site_ids1
      assert length(site_ids1) == 2

      assert s3.id in site_ids2
      assert s4.id in site_ids2
      assert s5.id in site_ids2
      assert length(site_ids2) == 3

      {:ok, ids_from_db1} = ConsolidatedView.site_ids(team1)
      assert Enum.sort(ids_from_db1) == Enum.sort(site_ids1)

      {:ok, ids_from_db2} = ConsolidatedView.site_ids(team2)
      assert Enum.sort(ids_from_db2) == Enum.sort(site_ids2)
    end

    test "small refresh adds a site to existing consolidation", %{test: test} do
      start_test_cache(test)

      owner = new_user()
      new_site(owner: owner, updated_at: yesterday())
      consolidated_view = new_site(owner: owner, updated_at: yesterday(), consolidated: true)

      :ok = Cache.refresh_all(cache_name: test)

      assert [_] = Cache.get(consolidated_view.domain, cache_name: test, force?: true)

      new_site(owner: owner)

      :ok = Cache.refresh_updated_recently(cache_name: test)
      assert [_, _] = Cache.get(consolidated_view.domain, cache_name: test, force?: true)
    end

    test "small refresh re-consolidates", %{test: test} do
      start_test_cache(test)

      owner = new_user()
      new_site(owner: owner, updated_at: yesterday())

      team = team_of(owner)

      consolidated_view = new_consolidated_view(team)

      :ok = Cache.refresh_updated_recently(cache_name: test)

      assert [_] = Cache.get(consolidated_view.domain, cache_name: test, force?: true)
    end

    test "get_from_source/1", %{test: test} do
      user = new_user()
      new_site(owner: user)
      new_site(owner: user)
      team = team_of(user)
      consolidated_view = new_consolidated_view(team)

      start_test_cache(test)
      :ok = Cache.refresh_all(cache_name: test)

      result = Cache.get(consolidated_view.domain, cache_name: test, force?: true)
      assert ^result = Cache.get(consolidated_view.domain)
      assert ^result = Cache.get_from_source(consolidated_view.domain)
    end

    defp start_test_cache(cache_name) do
      %{start: {m, f, a}} = Cache.child_spec(cache_name: cache_name)
      apply(m, f, a)
    end

    defp yesterday() do
      DateTime.shift(
        DateTime.utc_now(),
        day: -1
      )
    end
  end
end
