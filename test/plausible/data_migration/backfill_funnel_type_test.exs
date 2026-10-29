defmodule Plausible.DataMigration.BackfillFunnelTypeTest do
  use Plausible

  on_ee do
    use Plausible.DataCase, async: true

    import ExUnit.CaptureIO

    alias Plausible.DataMigration.BackfillFunnelType
    alias Plausible.Funnels
    alias Plausible.Goals
    alias Plausible.Repo

    describe "run/1" do
      test "runs for empty dataset" do
        dry_run_output =
          capture_io(fn ->
            assert :ok = BackfillFunnelType.run()
          end)

        assert dry_run_output =~ "DRY RUN: true"
        assert dry_run_output =~ "Found 0 funnels with funnel_type out of sync"
        refute dry_run_output =~ "Finished syncing"

        real_run_output =
          capture_io(fn ->
            assert :ok = BackfillFunnelType.run(dry_run?: false)
          end)

        assert real_run_output =~ "DRY RUN: false"
        assert real_run_output =~ "Found 0 funnels with funnel_type out of sync"
        assert real_run_output =~ "Finished syncing funnel type for 0 funnels!"
      end

      test "updates out of sync funnels" do
        site = new_site()

        {:ok, g1} = Goals.create(site, %{"page_path" => "/go/to/blog/**"})
        {:ok, g2} = Goals.create(site, %{"event_name" => "Signup"})
        {:ok, g3} = Goals.create(site, %{"page_path" => "/checkout"})

        {:ok, valid_sequential} =
          Funnels.create(site, "Valid sequential", [g1, g2, g3], funnel_type: :sequential)

        {:ok, valid_strict} =
          Funnels.create(site, "Valid strict", [g1, g2, g3], funnel_type: :strict)

        {:ok, valid_flexible} =
          Funnels.create(site, "Valid flexible", [g1, g2, g3], funnel_type: :flexible)

        {:ok, invalid_sequential} =
          Funnels.create(site, "Invalid sequential", [g1, g2, g3], funnel_type: :strict)

        invalid_sequential =
          invalid_sequential
          |> Ecto.Changeset.change(strict_order: false, first_and_last: false)
          |> Repo.update!()

        {:ok, invalid_strict} =
          Funnels.create(site, "Invalid strict", [g1, g2, g3], funnel_type: :sequential)

        invalid_strict =
          invalid_strict
          |> Ecto.Changeset.change(strict_order: true, first_and_last: false)
          |> Repo.update!()

        {:ok, invalid_flexible} =
          Funnels.create(site, "Invalid flexible", [g1, g2, g3], funnel_type: :sequential)

        invalid_flexible =
          invalid_flexible
          |> Ecto.Changeset.change(strict_order: false, first_and_last: true)
          |> Repo.update!()

        real_run_output =
          capture_io(fn ->
            assert :ok = BackfillFunnelType.run(dry_run?: false)
          end)

        assert real_run_output =~ "DRY RUN: false"
        assert real_run_output =~ "Found 3 funnels with funnel_type out of sync"
        assert real_run_output =~ "Finished syncing funnel type for 3 funnels!"

        assert Repo.reload!(valid_sequential).funnel_type == :sequential
        assert Repo.reload!(valid_strict).funnel_type == :strict
        assert Repo.reload!(valid_flexible).funnel_type == :flexible
        assert Repo.reload!(invalid_sequential).funnel_type == :sequential
        assert Repo.reload!(invalid_strict).funnel_type == :strict
        assert Repo.reload!(invalid_flexible).funnel_type == :flexible

        real_run_output_repeat =
          capture_io(fn ->
            assert :ok = BackfillFunnelType.run(dry_run?: false)
          end)

        assert real_run_output_repeat =~ "DRY RUN: false"
        assert real_run_output_repeat =~ "Found 0 funnels with funnel_type out of sync"
        assert real_run_output_repeat =~ "Finished syncing funnel type for 0 funnels!"
      end
    end
  end
end
