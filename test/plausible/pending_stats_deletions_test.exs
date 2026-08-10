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

      assert {:ok, pending_deletion} = PendingStatsDeletions.store(site)
      assert pending_deletion.reason == :user_request
    end

    test "accepts an explicit reason" do
      site = new_site()

      assert {:ok, pending_deletion} = PendingStatsDeletions.store(site, :user_request)
      assert pending_deletion.reason == :user_request
    end

    test "stores a nil stats range when the site has no stats" do
      site = new_site()

      assert {:ok, pending_deletion} = PendingStatsDeletions.store(site)

      assert pending_deletion.stats_start_date == nil
      assert pending_deletion.stats_end_date == nil
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

    test "returns an error when reason is not a recognized value" do
      site = new_site()

      assert {:error, changeset} = PendingStatsDeletions.store(site, :not_a_real_reason)
      assert {"is invalid", _} = changeset.errors[:reason]
    end
  end
end
