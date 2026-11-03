defmodule Plausible.SiteTest do
  use Plausible.DataCase
  alias Plausible.Site

  doctest Plausible.Site

  describe "new/1" do
    test "sets onboarding_status to :new_site by default" do
      changeset = Site.new(%{"domain" => "example.com", "timezone" => "Europe/London"})

      assert Ecto.Changeset.get_change(changeset, :onboarding_status) == :new_site
    end

    test "sets onboarding_status to :completed for a consolidated site" do
      changeset =
        Site.new(%{
          "domain" => "example.com",
          "timezone" => "Europe/London",
          "consolidated" => true
        })

      assert Ecto.Changeset.apply_changes(changeset).onboarding_status == :completed
    end
  end

  describe "tz_offset/2" do
    test "returns offset from utc in seconds" do
      site = build(:site, timezone: "US/Eastern")

      assert Site.tz_offset(site, ~U[2023-01-01 00:00:00Z]) == -18_000
    end

    test "returns correct offset from utc during summer time" do
      site = build(:site, timezone: "US/Eastern")

      assert Site.tz_offset(site, ~U[2023-07-01 00:00:00Z]) == -14_400
    end

    test "returns correct offset when changing from winter to summer time" do
      site = build(:site, timezone: "US/Eastern")

      assert Site.tz_offset(site, ~U[2023-03-12 06:59:59Z]) == -18_000
      assert Site.tz_offset(site, ~U[2023-03-12 07:00:00Z]) == -14_400
    end

    test "returns correct offset when changing from summer to winter time" do
      site = build(:site, timezone: "US/Eastern")

      assert Site.tz_offset(site, ~U[2023-11-05 05:59:59Z]) == -14_400
      assert Site.tz_offset(site, ~U[2023-11-05 06:00:00Z]) == -18_000
    end
  end

  describe "put_onboarding_status_advance/2" do
    test "advances onboarding_status forward" do
      site = insert(:site, onboarding_status: :new_site)

      changeset = Site.put_onboarding_status_advance(site, :verification_succeeded)

      assert Ecto.Changeset.get_change(changeset, :onboarding_status) == :verification_succeeded
    end

    test "can skip an intermediate status" do
      site = insert(:site, onboarding_status: :new_site)

      changeset = Site.put_onboarding_status_advance(site, :first_pageview)

      assert Ecto.Changeset.get_change(changeset, :onboarding_status) == :first_pageview
    end

    test "is a no-op when the site is already at the given status" do
      site = insert(:site, onboarding_status: :verification_succeeded)

      changeset = Site.put_onboarding_status_advance(site, :verification_succeeded)

      refute Ecto.Changeset.get_change(changeset, :onboarding_status)
    end

    test "is a no-op when the site is already past the given status" do
      site = insert(:site, onboarding_status: :completed)

      changeset = Site.put_onboarding_status_advance(site, :verification_succeeded)

      refute Ecto.Changeset.get_change(changeset, :onboarding_status)
    end

    test "composes with other changes on the same changeset" do
      site = insert(:site, onboarding_status: :new_site)

      changeset =
        site
        |> Site.set_stats_start_date(~D[2024-01-01])
        |> Site.put_onboarding_status_advance(:first_pageview)

      assert Ecto.Changeset.get_change(changeset, :stats_start_date) == ~D[2024-01-01]
      assert Ecto.Changeset.get_change(changeset, :onboarding_status) == :first_pageview
    end

    test "persists via Repo.update!" do
      site = insert(:site, onboarding_status: :new_site)

      updated_site =
        site
        |> Site.put_onboarding_status_advance(:verification_succeeded)
        |> Repo.update!()

      assert updated_site.onboarding_status == :verification_succeeded
      assert Repo.reload!(site).onboarding_status == :verification_succeeded
    end
  end
end
