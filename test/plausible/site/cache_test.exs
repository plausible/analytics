defmodule Plausible.Site.CacheTest do
  use Plausible.DataCase, async: true
  use Plausible.Teams.Test

  alias Plausible.{Site, Goal}
  alias Plausible.Site.Cache

  describe "public cache interface" do
    @tag :skip
    test "cache caches sites", %{test: test} do
      {:ok, _} =
        Supervisor.start_link([{Cache, [cache_name: test, child_id: :test_cache_caches_id]}],
          strategy: :one_for_one,
          name: :"cache_supervisor_#{test}"
        )

      %{id: first_id} = site1 = new_site(domain: "site1.example.com")

      owner = new_user(team: [accept_traffic_until: ~D[2021-01-01]])
      viewer = new_user(team: [accept_traffic_until: ~D[2022-01-01]])
      admin = new_user(team: [accept_traffic_until: ~D[2020-01-01]])

      site = new_site(owner: owner, domain: "site2.example.com")
      add_guest(site, user: viewer, role: :viewer)
      add_guest(site, user: admin, role: :editor)

      :ok = Cache.refresh_all(cache_name: test)

      {:ok, _} = Plausible.Repo.delete(site1)

      assert Cache.size(test) == 2

      assert %Site{from_cache?: true, id: ^first_id} =
               Cache.get("site1.example.com", force?: true, cache_name: test)

      assert %Site{from_cache?: true} =
               Cache.get("site2.example.com", force?: true, cache_name: test)

      assert %Site{from_cache?: false, owner: %{accept_traffic_until: ~D[2021-01-01]}} =
               Cache.get("site2.example.com", cache_name: test)

      refute Cache.get("site3.example.com", cache_name: test, force?: true)
    end

    @tag :ee_only
    test "cache caches revenue goals", %{test: test} do
      {:ok, _} =
        Supervisor.start_link(
          [{Cache, [cache_name: test, child_id: :test_cache_caches_revenue_goals]}],
          strategy: :one_for_one,
          name: :"cache_supervisor_#{test}"
        )

      %{id: site_id} = site = new_site(domain: "site1.example.com")

      {:ok, _goal} =
        Plausible.Goals.create(site, %{"event_name" => "Purchase", "currency" => :BRL})

      {:ok, _goal} =
        Plausible.Goals.create(site, %{"event_name" => "Add to Cart", "currency" => :USD})

      {:ok, _goal} = Plausible.Goals.create(site, %{"event_name" => "Click", "currency" => nil})

      :ok = Cache.refresh_all(cache_name: test)

      {:ok, _} = Plausible.Repo.delete(site)

      assert %Site{from_cache?: true, id: ^site_id, revenue_goals: cached_goals} =
               Cache.get("site1.example.com", force?: true, cache_name: test)

      assert [
               %Goal{event_name: "Add to Cart", currency: :USD},
               %Goal{event_name: "Purchase", currency: :BRL}
             ] = Enum.sort_by(cached_goals, & &1.event_name)
    end

    @tag :ee_only
    test "cache caches revenue goals with event refresh", %{test: test} do
      {:ok, _} =
        Supervisor.start_link(
          [{Cache, [cache_name: test, child_id: :test_revenue_goals_event_refresh]}],
          strategy: :one_for_one,
          name: :"cache_supervisor_#{test}"
        )

      yesterday = DateTime.utc_now() |> DateTime.add(-1 * 60 * 60 * 24)

      # the site was added yesterday so full refresh will pick it up
      %{id: site_id} = site = new_site(domain: "site1.example.com", updated_at: yesterday)

      # the goal was added yesterday so full refresh will pick it up
      Plausible.Goals.create(site, %{"event_name" => "Purchase", "currency" => :BRL},
        now: yesterday
      )

      # this goal is added "just now"
      Plausible.Goals.create(site, %{"event_name" => "Add to Cart", "currency" => :USD})
      # and this one does not matter
      Plausible.Goals.create(site, %{"event_name" => "Click", "currency" => nil})

      # at this point, we have 3 goals associated with the cached struct
      :ok = Cache.refresh_all(cache_name: test)

      # the goal was added 70 seconds ago so partial refresh should pick it up and merge with the rest of goals
      Plausible.Goals.create(
        site,
        %{"event_name" => "Purchase2", "currency" => :BRL},
        now: DateTime.add(DateTime.utc_now(), -70)
      )

      :ok = Cache.refresh_updated_recently(cache_name: test)

      assert %Site{from_cache?: true, id: ^site_id, revenue_goals: cached_goals} =
               Cache.get("site1.example.com", force?: true, cache_name: test)

      assert [
               %Goal{event_name: "Add to Cart", currency: :USD},
               %Goal{event_name: "Purchase", currency: :BRL},
               %Goal{event_name: "Purchase2", currency: :BRL}
             ] = Enum.sort_by(cached_goals, & &1.event_name)
    end

    test "cache is ready when no sites exist in the db", %{test: test} do
      {:ok, _} = start_test_cache(test)
      assert Cache.ready?(test)
    end

    test "cache is not ready when sites exist in the db but cache needs refresh", %{test: test} do
      {:ok, _} = start_test_cache(test)
      insert(:site)
      refute Cache.ready?(test)
    end

    test "cache is ready when refreshed", %{test: test} do
      {:ok, _} = start_test_cache(test)
      new_site()
      :ok = Cache.refresh_all(cache_name: test)
      assert Cache.ready?(test)
    end

    test "cache allows lookups for sites with changed domain", %{test: test} do
      {:ok, _} = start_test_cache(test)
      new_site(domain: "new.example.com", domain_changed_from: "old.example.com")
      :ok = Cache.refresh_all(cache_name: test)

      assert Cache.get("old.example.com", force?: true, cache_name: test)
      assert Cache.get("new.example.com", force?: true, cache_name: test)
    end

    test "cache exposes hit rate", %{test: test} do
      {:ok, _} = start_test_cache(test)

      new_site(domain: "site1.example.com")
      :ok = Cache.refresh_all(cache_name: test)

      assert Cache.hit_rate(test) == 0
      assert Cache.get("site1.example.com", force?: true, cache_name: test)
      assert Cache.hit_rate(test) == 100
      refute Cache.get("nonexisting.example.com", force?: true, cache_name: test)
      assert Cache.hit_rate(test) == 50
    end

    test "only recently updated sites can be refreshed", %{test: test} do
      {:ok, _} = start_test_cache(test)

      domain1 = "site1.example.com"
      domain2 = "nonexisting.example.com"

      cache_opts = [cache_name: test, force?: true]

      yesterday = DateTime.utc_now() |> DateTime.add(-1 * 60 * 60 * 24)
      new_site(domain: domain1, inserted_at: yesterday, updated_at: yesterday)

      new_site(domain: domain2)

      assert Cache.get(domain1, cache_opts) == nil
      assert Cache.get(domain2, cache_opts) == nil

      assert :ok = Cache.refresh_updated_recently(cache_opts)

      refute Cache.get(domain1, cache_opts)
      assert %Site{domain: ^domain2} = Cache.get(domain2, cache_opts)
    end

    test "sites with recently changed domains are refreshed", %{test: test} do
      {:ok, _} = start_test_cache(test)
      cache_opts = [cache_name: test, force?: true]

      domain1 = "first.example.com"
      domain2 = "second.example.com"

      site = new_site(domain: domain1)
      assert :ok = Cache.refresh_updated_recently(cache_opts)
      assert item = Cache.get(domain1, cache_opts)
      refute item.domain_changed_from

      # change domain1 to domain2

      {:ok, _site} = Site.Domain.change(site, domain2)

      # small refresh keeps both items in cache

      assert :ok = Cache.refresh_updated_recently(cache_opts)
      assert item_by_domain1 = Cache.get(domain1, cache_opts)
      assert item_by_domain2 = Cache.get(domain2, cache_opts)

      assert item_by_domain1 == item_by_domain2
      assert item_by_domain1.domain == domain2
      assert item_by_domain1.domain_changed_from == domain1

      # domain_changed_from gets no longer tracked

      {:ok, _} = Site.Domain.expire_change_transitions(-1)

      # full refresh removes the stale entry

      assert :ok = Cache.refresh_all(cache_opts)

      refute Cache.get(domain1, cache_opts)
      assert item = Cache.get(domain2, cache_opts)
      refute item.domain_changed_from
    end

    test "refreshing all sites sends a telemetry event",
         %{
           test: test
         } do
      domain = "site1.example.com"
      insert(:site, domain: domain)

      :ok =
        start_test_cache_with_telemetry_handler(test,
          event: Cache.telemetry_event_refresh(test, :all)
        )

      Cache.refresh_all(force?: true, cache_name: test)
      assert_receive {:telemetry_handled, %{}}
    end

    test "get_site_id/2", %{test: test} do
      {:ok, _} = start_test_cache(test)

      site = new_site()

      domain1 = site.domain
      domain2 = "nonexisting.example.com"

      :ok = Cache.refresh_all(cache_name: test)

      assert site.id == Cache.get_site_id(domain1, force?: true, cache_name: test)
      assert is_nil(Cache.get_site_id(domain2, force?: true, cache_name: test))
    end
  end

  describe "merging the cache" do
    test "merging adds new items", %{test: test} do
      {:ok, _} = start_test_cache(test)

      :ok = Cache.merge_items([{"item1", nil, :item1}], cache_name: test)
      assert :item1 == Cache.get("item1", cache_name: test, force?: true)
    end

    test "merging no new items leaves the old cache intact", %{test: test} do
      {:ok, _} = start_test_cache(test)

      :ok = Cache.merge_items([{"item1", nil, :item1}], cache_name: test)
      :ok = Cache.merge_items([], cache_name: test)
      assert :item1 == Cache.get("item1", cache_name: test, force?: true)
    end

    test "merging removes stale items", %{test: test} do
      {:ok, _} = start_test_cache(test)

      :ok = Cache.merge_items([{"item1", nil, :item1}], cache_name: test)
      :ok = Cache.merge_items([{"item2", nil, :item2}], cache_name: test)

      refute Cache.get("item1", cache_name: test, force?: true)
      assert Cache.get("item2", cache_name: test, force?: true)
    end

    test "merging optionally leaves stale items intact", %{test: test} do
      {:ok, _} = start_test_cache(test)

      :ok = Cache.merge_items([{"item1", nil, :item1}], cache_name: test)

      :ok =
        Cache.merge_items([{"item2", nil, :item2}], cache_name: test, delete_stale_items?: false)

      assert Cache.get("item1", cache_name: test, force?: true)
      assert Cache.get("item2", cache_name: test, force?: true)
    end

    test "merging updates changed items", %{test: test} do
      {:ok, _} = start_test_cache(test)

      :ok = Cache.merge_items([{"item1", nil, :item1}, {"item2", nil, :item2}], cache_name: test)

      :ok =
        Cache.merge_items([{"item1", nil, :changed}, {"item2", nil, :item2}], cache_name: test)

      assert :changed == Cache.get("item1", cache_name: test, force?: true)
      assert :item2 == Cache.get("item2", cache_name: test, force?: true)
    end

    test "merging keeps secondary keys", %{test: test} do
      {:ok, _} = start_test_cache(test)

      :ok = Cache.merge_items([{"item1", nil, :item1}], cache_name: test)
      :ok = Cache.merge_items([{"item2", "item1", :updated}], cache_name: test)
      assert :updated == Cache.get("item1", cache_name: test, force?: true)
      assert :updated == Cache.get("item2", cache_name: test, force?: true)
    end

    @items1 for i <- 1..200_000, do: {i, nil, :batch1}
    @items2 for _ <- 1..200_000, do: {Enum.random(1..400_000), nil, :batch2}
    @max_seconds 2
    test "merging large sets is expected to be under #{@max_seconds} seconds", %{test: test} do
      {:ok, _} = start_test_cache(test)

      {t1, :ok} =
        :timer.tc(fn ->
          :ok = Cache.merge_items(@items1, cache_name: test)
        end)

      {t2, :ok} =
        :timer.tc(fn ->
          :ok = Cache.merge_items(@items1, cache_name: test)
        end)

      {t3, :ok} =
        :timer.tc(fn ->
          :ok = Cache.merge_items(@items2, cache_name: test)
        end)

      assert t1 / 1_000_000 <= @max_seconds
      assert t2 / 1_000_000 <= @max_seconds
      assert t3 / 1_000_000 <= @max_seconds
    end

    test "deleted sites don't stay in cache on another refresh", %{test: test} do
      {:ok, _} = start_test_cache(test)

      domain1 = "site1.example.com"
      domain2 = "site2.example.com"

      site1 = new_site(domain: domain1)
      _site2 = new_site(domain: domain2)

      cache_opts = [cache_name: test, force?: true]

      :ok = Cache.refresh_all(cache_opts)

      assert Cache.get(domain1, cache_opts)
      assert Cache.get(domain2, cache_opts)

      Repo.delete!(site1)

      :ok = Cache.refresh_all(cache_opts)

      assert Cache.get(domain2, cache_opts)

      refute Cache.get(domain1, cache_opts)
      :ok = Cache.refresh_all(cache_opts)
      refute Cache.get(domain1, cache_opts)
    end
  end

  defp start_test_cache(cache_name) do
    %{start: {m, f, a}} = Cache.child_spec(cache_name: cache_name)
    apply(m, f, a)
  end

  defp start_test_cache_with_telemetry_handler(test, event: event) do
    {:ok, _} = start_test_cache(test)
    test_pid = self()

    :telemetry.attach(
      "#{test}-telemetry-handler",
      event,
      fn ^event, %{duration: d}, metadata, _ when is_integer(d) ->
        send(test_pid, {:telemetry_handled, metadata})
      end,
      %{}
    )
  end
end
