defmodule Plausible.Site.SiteRemovalTest do
  use Plausible.DataCase, async: true
  use Oban.Testing, repo: Plausible.Repo

  alias Plausible.Site.Removal
  alias Plausible.Sites
  alias Plausible.Workers.StatsRemoval

  describe "execution and scheduling" do
    test "site from postgres is immediately deleted" do
      site = insert(:site)
      assert {:ok, context} = Removal.run(site.domain)
      assert context.delete_all == {1, nil}
      assert context.site_id == site.id
      refute Sites.get_by_domain(site.domain)
    end

    test "deletion is idempotent" do
      assert {:ok, context} = Removal.run("some.example.com")
      assert context.delete_all == {0, nil}
    end

    test "stats deletion job is scheduled when no site exists in postgres" do
      assert {:ok, _} = Removal.run("a.domain.example.com")

      assert_enqueued(
        worker: StatsRemoval,
        args: %{"domain" => "a.domain.example.com", "site_id" => nil}
      )
    end

    test "stats deletion job is scheduled when site exists in postgres" do
      site = insert(:site)
      assert {:ok, _} = Removal.run(site.domain)

      assert_enqueued(
        worker: StatsRemoval,
        args: %{"domain" => site.domain, "site_id" => site.id}
      )
    end

    test "stats deletion is always scheduled ~20m in the future" do
      assert {:ok, _} = Removal.run("foo.example.com")

      in_20m = DateTime.add(DateTime.utc_now(), 1200, :second)

      assert_enqueued(
        worker: StatsRemoval,
        scheduled_at: {in_20m, delta: 5}
      )
    end

    test "stats deletion is always scheduled late enough for sites cache to expire" do
      delay_ms = Removal.stats_deletion_delay_seconds() * 1000
      assert delay_ms > Plausible.Site.Cache.Warmer.interval()
    end
  end

  describe "the background worker" do
    test "the job runs deletes at clickhouse" do
      assert {:ok, %{"events" => r, "sessions" => r}} =
               perform_job(StatsRemoval, %{"domain" => "foo.example.com"})

      assert %Clickhousex.Result{command: :updated} = r

      assert {:ok, %{"events" => r, "sessions" => r, "imported_browsers" => r}} =
               perform_job(StatsRemoval, %{"domain" => "foo.example.com", "site_id" => 777})

      assert %Clickhousex.Result{command: :updated} = r
    end
  end

  describe "integration" do
    setup do
      site = insert(:site, stats_start_date: ~D[2020-01-01])

      populate_stats(site, [
        build(:pageview),
        build(:imported_visitors),
        build(:imported_sources),
        build(:imported_pages),
        build(:imported_entry_pages),
        build(:imported_exit_pages),
        build(:imported_locations),
        build(:imported_devices),
        build(:imported_browsers),
        build(:imported_operating_systems)
      ])

      {:ok, %{site: site}}
    end

    test "the job actually removes stats from clickhouse", %{site: site} do
      Enum.each(Plausible.Imported.tables(), fn table ->
        query = from(imported in table, where: imported.site_id == ^site.id)
        assert await_clickhouse_count(query, 1)
      end)

      events_query = from(s in Plausible.ClickhouseEvent, where: s.domain == ^site.domain)
      assert await_clickhouse_count(events_query, 1)

      sessions_query = from(s in Plausible.ClickhouseSession, where: s.domain == ^site.domain)
      assert await_clickhouse_count(sessions_query, 1)

      perform_job(StatsRemoval, %{"domain" => site.domain, "site_id" => site.id})

      assert await_clickhouse_count(events_query, 0)
      assert await_clickhouse_count(sessions_query, 0)

      Enum.each(Plausible.Imported.tables(), fn table ->
        query = from(imported in table, where: imported.site_id == ^site.id)
        assert await_clickhouse_count(query, 0)
      end)
    end
  end
end
