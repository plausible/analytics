defmodule Plausible.Workers.SetLegacyTimeOnPageCutoffTest do
  use Plausible.DataCase
  use Plausible.TestUtils
  use Plausible

  alias Plausible.Workers.SetLegacyTimeOnPageCutoff

  test "sets cutoff for small site with engagement" do
    site = insert(:site, legacy_time_on_page_cutoff: nil)

    populate_stats(site, [
      build(:pageview, user_id: 13, timestamp: hours_ago(25)),
      build(:engagement, user_id: 13, engagement_time: 10, timestamp: hours_ago(25))
    ])

    SetLegacyTimeOnPageCutoff.perform(nil)
    assert Repo.reload!(site).legacy_time_on_page_cutoff == Date.utc_today()
  end

  test "does not update an already set cutoff" do
    site = insert(:site, legacy_time_on_page_cutoff: ~D[1970-01-01])

    populate_stats(site, [
      build(:pageview, user_id: 13, timestamp: hours_ago(25)),
      build(:engagement, user_id: 13, engagement_time: 10, timestamp: hours_ago(25))
    ])

    SetLegacyTimeOnPageCutoff.perform(nil)
    assert Repo.reload!(site).legacy_time_on_page_cutoff == ~D[1970-01-01]
  end

  test "sets cutoff for large site with complete engagement" do
    site = insert(:site, legacy_time_on_page_cutoff: nil)

    1..2500
    |> Enum.flat_map(fn i ->
      hour = 25 + rem(i, 24)

      [
        build(:pageview, user_id: i, timestamp: hours_ago(hour)),
        build(:engagement, user_id: i, engagement_time: 10, timestamp: hours_ago(hour))
      ]
    end)
    |> then(&populate_stats(site, &1))

    SetLegacyTimeOnPageCutoff.perform(nil)
    assert Repo.reload!(site).legacy_time_on_page_cutoff == Date.utc_today()
  end

  test "does not update large site site with incomplete engagement" do
    site = insert(:site, legacy_time_on_page_cutoff: nil)

    1..2500
    |> Enum.flat_map(fn i ->
      [
        build(:pageview, user_id: i, timestamp: hours_ago(25)),
        build(:engagement, user_id: i, engagement_time: 10, timestamp: hours_ago(25))
      ]
    end)
    |> then(&populate_stats(site, &1))

    SetLegacyTimeOnPageCutoff.perform(nil)
    assert Repo.reload!(site).legacy_time_on_page_cutoff == nil
  end

  test "does not update site that already has cutoff set" do
    site = insert(:site, legacy_time_on_page_cutoff: ~D[2025-01-01])

    populate_stats(site, [
      build(:pageview, user_id: 13, timestamp: hours_ago(25)),
      build(:engagement, user_id: 13, engagement_time: 10, timestamp: hours_ago(25))
    ])

    SetLegacyTimeOnPageCutoff.perform(nil)
    assert Repo.reload!(site).legacy_time_on_page_cutoff == ~D[2025-01-01]
  end

  test "ignores sites without relevant data" do
    site = insert(:site, legacy_time_on_page_cutoff: nil)

    populate_stats(site, [
      build(:pageview, user_id: 13, timestamp: hours_ago(1)),
      build(:engagement, user_id: 13, engagement_time: 10, timestamp: hours_ago(1))
    ])

    SetLegacyTimeOnPageCutoff.perform(nil)
    assert Repo.reload!(site).legacy_time_on_page_cutoff == nil
  end

  defp hours_ago(hours) do
    DateTime.utc_now() |> DateTime.add(-hours, :hour)
  end
end
