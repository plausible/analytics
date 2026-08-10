defmodule Plausible.PendingStatsDeletionsTest do
  use Plausible.DataCase, async: true

  alias Plausible.PendingStatsDeletion
  alias Plausible.PendingStatsDeletions

  describe "store/2" do
    test "creates a record with the site's stats range" do
      site = new_site()

      populate_stats(site, [
        build(:pageview, timestamp: ~N[2020-01-01 12:00:00]),
        build(:pageview, timestamp: ~N[2020-01-10 12:00:00])
      ])

      assert {:ok, %PendingStatsDeletion{} = pending_deletion} =
               PendingStatsDeletions.store(site)

      assert pending_deletion.site_id == site.id
      assert pending_deletion.stats_start_date == ~D[2020-01-01]
      assert pending_deletion.stats_end_date == ~D[2020-01-10]
      assert pending_deletion.reason == :user_request

      assert Repo.get_by(PendingStatsDeletion, site_id: site.id) == pending_deletion
    end

    test "defaults reason to :user_request" do
      site = new_site()
      populate_stats(site, [build(:pageview)])

      assert {:ok, pending_deletion} = PendingStatsDeletions.store(site)
      assert pending_deletion.reason == :user_request
    end

    test "accepts an explicit reason" do
      site = new_site()
      populate_stats(site, [build(:pageview)])

      assert {:ok, pending_deletion} = PendingStatsDeletions.store(site, :user_request)
      assert pending_deletion.reason == :user_request
    end

    test "does not insert anything when the site has no stats to delete" do
      site = new_site()

      assert {:ok, nil} = PendingStatsDeletions.store(site)

      refute Repo.get_by(PendingStatsDeletion, site_id: site.id)
    end

    test "takes imported stats into account" do
      site = new_site()
      insert(:site_import, site: site, start_date: ~D[2018-01-01], end_date: ~D[2018-06-01])

      populate_stats(site, [
        build(:pageview, timestamp: ~N[2020-01-01 12:00:00])
      ])

      assert {:ok, pending_deletion} = PendingStatsDeletions.store(site)

      assert pending_deletion.stats_start_date == ~D[2018-01-01]
      assert pending_deletion.stats_end_date == ~D[2020-01-01]
    end
  end

  describe "list/1" do
    test "returns empty site_ids and a nil range when there are no pending stats deletions" do
      assert PendingStatsDeletions.list() == %{
               site_ids: [],
               stats_start: nil,
               stats_end: nil
             }
    end

    test "returns the distinct site_ids and the cumulative range across all records" do
      insert(:pending_stats_deletion,
        site_id: 1,
        stats_start_date: ~D[2020-01-01],
        stats_end_date: ~D[2020-01-10]
      )

      insert(:pending_stats_deletion,
        site_id: 1,
        stats_start_date: ~D[2019-06-01],
        stats_end_date: ~D[2020-01-05]
      )

      insert(:pending_stats_deletion,
        site_id: 2,
        stats_start_date: ~D[2021-01-01],
        stats_end_date: ~D[2021-02-01]
      )

      assert PendingStatsDeletions.list() == %{
               site_ids: [1, 2],
               stats_start: ~D[2019-06-01],
               stats_end: ~D[2021-02-01]
             }
    end

    test "considers records with the given reason" do
      insert(:pending_stats_deletion,
        site_id: 1,
        stats_start_date: ~D[2020-01-01],
        stats_end_date: ~D[2020-01-10],
        reason: :user_request
      )

      assert PendingStatsDeletions.list(:user_request) == %{
               site_ids: [1],
               stats_start: ~D[2020-01-01],
               stats_end: ~D[2020-01-10]
             }
    end
  end

  describe "backfill_orphaned_sites/0" do
    @tag :slow
    test "records a pending stats deletion for a site with clickhouse data but no postgres row" do
      orphaned_site = new_site()

      populate_stats(orphaned_site, [
        build(:pageview, timestamp: ~N[2020-01-01 12:00:00]),
        build(:pageview, timestamp: ~N[2020-01-10 12:00:00])
      ])

      Repo.delete!(orphaned_site)

      assert {:ok, count} = PendingStatsDeletions.backfill_orphaned_sites()
      assert count >= 1

      pending_deletion = Repo.get_by(PendingStatsDeletion, site_id: orphaned_site.id)
      assert pending_deletion.stats_start_date == ~D[2020-01-01]
      assert pending_deletion.stats_end_date == ~D[2020-01-10]
      assert pending_deletion.reason == :user_request
    end

    @tag :slow
    test "does not record anything for a site that still exists in postgres" do
      site = new_site()
      populate_stats(site, [build(:pageview)])

      PendingStatsDeletions.backfill_orphaned_sites()

      refute Repo.get_by(PendingStatsDeletion, site_id: site.id)
    end

    @tag :slow
    test "does not create a duplicate record when run more than once" do
      orphaned_site = new_site()
      populate_stats(orphaned_site, [build(:pageview)])
      Repo.delete!(orphaned_site)

      assert {:ok, _} = PendingStatsDeletions.backfill_orphaned_sites()
      assert {:ok, _} = PendingStatsDeletions.backfill_orphaned_sites()

      matching_records =
        from(p in PendingStatsDeletion, where: p.site_id == ^orphaned_site.id)
        |> Repo.aggregate(:count)

      assert matching_records == 1
    end
  end
end
