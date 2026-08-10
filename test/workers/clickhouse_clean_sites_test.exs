defmodule Plausible.Workers.ClickhouseCleanSitesTest do
  use Plausible.DataCase
  import Plausible.Factory

  alias Plausible.Ingestion.Counters.Record
  alias Plausible.PendingStatsDeletion
  alias Plausible.Workers.ClickhouseCleanSites

  @tag :slow
  test "deletes data from events and sessions tables for sites pending stats deletion" do
    site = new_site()
    deleted_site = new_site()

    populate_stats(site, [
      build(:pageview)
    ])

    populate_stats(deleted_site, [
      build(:pageview),
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

    insert_ingest_counter(site.id)
    insert_ingest_counter(deleted_site.id)

    assert {:ok, _} = Plausible.Site.Removal.run(deleted_site)

    ClickhouseCleanSites.perform(nil)

    assert_count(deleted_site, "events_v2", 0)
    assert_count(deleted_site, "sessions_v2", 0)
    assert_count(deleted_site, "imported_visitors", 0)
    assert_count(deleted_site, "imported_sources", 0)
    assert_count(deleted_site, "imported_pages", 0)
    assert_count(deleted_site, "imported_entry_pages", 0)
    assert_count(deleted_site, "imported_exit_pages", 0)
    assert_count(deleted_site, "imported_locations", 0)
    assert_count(deleted_site, "imported_devices", 0)
    assert_count(deleted_site, "imported_browsers", 0)
    assert_count(deleted_site, "imported_operating_systems", 0)
    # ingest_counters has a projection, so it's cleared via a mutation rather
    # than a lightweight delete - regression coverage for that special case
    assert_count(deleted_site, "ingest_counters", 0)
    assert_count(site, "events_v2", 1)
    assert_count(site, "sessions_v2", 1)
    assert_count(site, "ingest_counters", 1)

    refute Repo.get_by(PendingStatsDeletion, site_id: deleted_site.id)
  end

  @tag :slow
  test "deletes data spanning multiple monthly partitions" do
    deleted_site = new_site()

    populate_stats(deleted_site, [
      build(:pageview, timestamp: ~N[2020-01-15 12:00:00]),
      build(:pageview, timestamp: ~N[2020-03-15 12:00:00])
    ])

    assert {:ok, _} = Plausible.Site.Removal.run(deleted_site)

    ClickhouseCleanSites.perform(nil)

    assert_count(deleted_site, "events_v2", 0)
    assert_count(deleted_site, "sessions_v2", 0)
  end

  @tag :slow
  test "emits telemetry for the run and for each stage", %{test: test} do
    test_pid = self()

    telemetry_run = ClickhouseCleanSites.telemetry_run_event()
    telemetry_stage = ClickhouseCleanSites.telemetry_stage_duration()

    :telemetry.attach_many(
      "#{test}-telemetry-handler",
      [telemetry_run, telemetry_stage],
      fn event, measurements, metadata, _ ->
        send(test_pid, {:telemetry_handled, event, measurements, metadata})
      end,
      %{}
    )

    deleted_site = new_site()

    populate_stats(deleted_site, [
      build(:pageview, timestamp: ~N[2020-01-15 12:00:00]),
      build(:pageview, timestamp: ~N[2020-03-15 12:00:00])
    ])

    assert {:ok, _} = Plausible.Site.Removal.run(deleted_site)

    ClickhouseCleanSites.perform(nil)

    assert_receive {:telemetry_handled, ^telemetry_stage, %{duration: _},
                     %{stage: "list_pending_deletions"}}

    assert_receive {:telemetry_handled, ^telemetry_run,
                     %{sites_count: 1, partitions_count: 3}, %{}}

    assert_receive {:telemetry_handled, ^telemetry_stage, %{duration: _},
                     %{stage: "partitioned_tables"}}

    assert_receive {:telemetry_handled, ^telemetry_stage, %{duration: _},
                     %{stage: "unpartitioned_tables"}}

    assert_receive {:telemetry_handled, ^telemetry_stage, %{duration: _},
                     %{stage: "mutation_only_tables"}}

    assert_receive {:telemetry_handled, ^telemetry_stage, %{duration: _},
                     %{stage: "clear_pending_deletions"}}
  end

  def assert_count(site, table, expected_count) do
    q = from(e in table, select: %{count: fragment("count()")}, where: e.site_id == ^site.id)
    await_clickhouse_count(q, expected_count)
  end

  defp insert_ingest_counter(site_id) do
    Plausible.IngestRepo.insert_all(Record, [
      %{
        event_timebucket: DateTime.utc_now() |> DateTime.truncate(:second),
        site_id: site_id,
        domain: "example.com",
        metric: "pageview",
        value: 1,
        tracker_script_version: 0
      }
    ])
  end
end
