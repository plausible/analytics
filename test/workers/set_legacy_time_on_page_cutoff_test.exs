defmodule Plausible.Workers.SetLegacyTimeOnPageCutoffTest do
  use Plausible.DataCase
  use Plausible.TestUtils
  use Plausible

  alias Plausible.Workers.SetLegacyTimeOnPageCutoff

  test "sets cutoff for small site with engagement" do
    site = create_site_with_cutoff(nil)

    populate_stats(site, [
      build(:pageview, user_id: 13, timestamp: ~U[2025-03-03 23:05:00Z]),
      build(:engagement, user_id: 13, engagement_time: 10, timestamp: ~U[2025-03-03 23:05:00Z])
    ])

    perform(~D[2025-03-05])
    assert Repo.reload!(site).legacy_time_on_page_cutoff == ~D[2025-03-05]
  end

  test "does not update an already set cutoff" do
    site = create_site_with_cutoff(~D[1970-01-01])

    populate_stats(site, [
      build(:pageview, user_id: 13, timestamp: ~U[2025-03-03 23:05:00Z]),
      build(:engagement, user_id: 13, engagement_time: 10, timestamp: ~U[2025-03-03 23:05:00Z])
    ])

    perform(~D[2025-03-05])
    assert Repo.reload!(site).legacy_time_on_page_cutoff == ~D[1970-01-01]
  end

  test "sets cutoff for large site with complete engagement" do
    site = create_site_with_cutoff(nil)

    1..2500
    |> Enum.flat_map(fn i ->
      hour = 25 + rem(i, 24)
      timestamp = ~U[2025-03-05 00:00:00Z] |> DateTime.add(-hour, :hour)

      [
        build(:pageview, user_id: i, timestamp: timestamp),
        build(:engagement, user_id: i, engagement_time: 10, timestamp: timestamp)
      ]
    end)
    |> then(&populate_stats(site, &1))

    perform(~D[2025-03-05])
    assert Repo.reload!(site).legacy_time_on_page_cutoff == ~D[2025-03-05]
  end

  test "does not update large site with incomplete engagement" do
    site = create_site_with_cutoff(nil)

    1..2500
    |> Enum.flat_map(fn i ->
      [
        build(:pageview, user_id: i, timestamp: ~U[2025-03-03 23:05:00Z]),
        build(:engagement, user_id: i, engagement_time: 10, timestamp: ~U[2025-03-03 23:05:00Z])
      ]
    end)
    |> then(&populate_stats(site, &1))

    perform(~D[2025-03-05])
    assert Repo.reload!(site).legacy_time_on_page_cutoff == nil
  end

  test "does not update site that already has cutoff set" do
    site = create_site_with_cutoff(~D[2025-01-01])

    populate_stats(site, [
      build(:pageview, user_id: 13, timestamp: ~U[2025-03-03 23:05:00Z]),
      build(:engagement, user_id: 13, engagement_time: 10, timestamp: ~U[2025-03-03 23:05:00Z])
    ])

    perform(~D[2025-03-05])
    assert Repo.reload!(site).legacy_time_on_page_cutoff == ~D[2025-01-01]
  end

  test "ignores sites without relevant data" do
    site = create_site_with_cutoff(nil)

    populate_stats(site, [
      build(:pageview, user_id: 13, timestamp: ~U[2025-03-04 22:05:00Z]),
      build(:engagement, user_id: 13, engagement_time: 10, timestamp: ~U[2025-03-04 22:05:00Z])
    ])

    perform(~D[2025-03-05])
    assert Repo.reload!(site).legacy_time_on_page_cutoff == nil
  end

  defp perform(date) do
    SetLegacyTimeOnPageCutoff.perform(%Oban.Job{args: %{"cutoff_date" => date}})
  end

  defp create_site_with_cutoff(cutoff) do
    site = insert(:site)

    # Work around model defaults
    site
    |> Plausible.Site.changeset(%{legacy_time_on_page_cutoff: cutoff})
    |> Plausible.Repo.update()

    site
  end
end
