defmodule Plausible.PendingStatsDeletionsTest do
  use Plausible.DataCase, async: true

  alias Plausible.PendingStatsDeletion
  alias Plausible.PendingStatsDeletions

  describe "store/2" do
    test "creates a record for the site" do
      site = new_site()

      assert {:ok, %PendingStatsDeletion{} = pending_deletion} = PendingStatsDeletions.store(site)

      assert pending_deletion.site_id == site.id
      assert pending_deletion.reason == :user_request

      assert Repo.get_by(PendingStatsDeletion, site_id: site.id) == pending_deletion
    end

    test "stores a record even if the site has no stats" do
      site = new_site()

      assert {:ok, %PendingStatsDeletion{}} = PendingStatsDeletions.store(site)

      assert Repo.get_by(PendingStatsDeletion, site_id: site.id)
    end

    test "defaults reason to :user_request" do
      site = new_site()

      assert {:ok, pending_deletion} = PendingStatsDeletions.store(site)
      assert pending_deletion.reason == :user_request
    end

    test "accepts an explicit reason" do
      site = new_site()

      assert {:ok, pending_deletion} = PendingStatsDeletions.store(site, :user_request)
      assert pending_deletion.reason == :user_request
    end
  end

  describe "list/1" do
    test "returns an empty list when there are no pending stats deletions" do
      assert PendingStatsDeletions.list() == []
    end

    test "returns the distinct site_ids" do
      insert(:pending_stats_deletion, site_id: 1, reason: :user_request)
      insert(:pending_stats_deletion, site_id: 1, reason: :user_request)
      insert(:pending_stats_deletion, site_id: 2, reason: :user_request)

      assert PendingStatsDeletions.list() == [1, 2]
    end

    test "only considers records with the given reason" do
      insert(:pending_stats_deletion, site_id: 1, reason: :user_request)

      assert PendingStatsDeletions.list(:user_request) == [1]
    end
  end

  describe "clear/2" do
    test "removes records for the given site_ids and reason" do
      insert(:pending_stats_deletion, site_id: 1, reason: :user_request)
      insert(:pending_stats_deletion, site_id: 2, reason: :user_request)

      assert {1, nil} = PendingStatsDeletions.clear([1])

      assert PendingStatsDeletions.list() == [2]
    end

    test "removes all matching records regardless of how many accumulated for a site" do
      insert(:pending_stats_deletion, site_id: 1, reason: :user_request)
      insert(:pending_stats_deletion, site_id: 1, reason: :user_request)

      assert {2, nil} = PendingStatsDeletions.clear([1])
      assert PendingStatsDeletions.list() == []
    end

    test "does not query the database when given an empty list of site_ids" do
      insert(:pending_stats_deletion, site_id: 1, reason: :user_request)

      assert {0, nil} = PendingStatsDeletions.clear([])
      assert Repo.get_by(PendingStatsDeletion, site_id: 1)
    end
  end

  describe "backfill_orphaned_sites/0" do
    test "records a pending stats deletion for a site with clickhouse data but no postgres row" do
      orphaned_site = new_site()

      populate_stats(orphaned_site, [
        build(:pageview, timestamp: ~N[2020-01-01 12:00:00])
      ])

      Repo.delete!(orphaned_site)

      assert {:ok, count} = PendingStatsDeletions.backfill_orphaned_sites()
      assert count >= 1

      assert Repo.get_by(PendingStatsDeletion, site_id: orphaned_site.id, reason: :user_request)
    end

    test "detects sites with only imported stats, not just events_v2/sessions_v2" do
      orphaned_site = new_site()

      populate_stats(orphaned_site, [
        build(:imported_visitors)
      ])

      Repo.delete!(orphaned_site)

      assert {:ok, _} = PendingStatsDeletions.backfill_orphaned_sites()

      assert Repo.get_by(PendingStatsDeletion, site_id: orphaned_site.id)
    end

    test "does not record anything for a site that still exists in postgres" do
      site = new_site()
      populate_stats(site, [build(:pageview)])

      PendingStatsDeletions.backfill_orphaned_sites()

      refute Repo.get_by(PendingStatsDeletion, site_id: site.id)
    end

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
