defmodule Plausible.DataMigration.PrefixTrackerScriptConfigurationIdTest do
  use Plausible.DataCase, async: true
  use Plausible.Teams.Test

  import ExUnit.CaptureIO
  import Ecto.Query

  alias Plausible.DataMigration.PrefixTrackerScriptConfigurationId
  alias Plausible.Site.TrackerScriptConfiguration
  alias Plausible.Site
  alias Plausible.Repo

  setup do
    # Clear the database tables before each test
    Repo.delete_all(TrackerScriptConfiguration)
    Repo.delete_all(Site)
    :ok
  end

  describe "running the migration" do
    setup do
      remove_constraint_if_exists()
      :ok
    end

    test "runs for empty dataset" do
      output =
        capture_io(fn ->
          assert :ok = PrefixTrackerScriptConfigurationId.run(2)
        end)

      assert output =~ "Found 0 total tracker configurations to process"
      assert output =~ "Migration completed!"
    end

    test "handles mixed configurations correctly" do
      # Mix of old and new format configurations
      _config1 = create_tracker_config("alpha")
      _config2 = create_tracker_config("pa-beta")
      _config3 = create_tracker_config("gamma")
      _config4 = create_tracker_config("delta")
      _config5 = create_tracker_config("epsilon")

      output =
        capture_io(fn ->
          assert :ok = PrefixTrackerScriptConfigurationId.run(2)
        end)

      assert output =~ "Found 4 total tracker configurations to process"
      assert output =~ "Processing batch 1 (1-2 of 4)"
      assert output =~ "Processing batch 2 (3-4 of 4)"
      assert output =~ "Migration completed!"

      # Verify only old format configurations were updated
      updated_configs =
        Repo.all(
          from c in TrackerScriptConfiguration,
            where: c.id in ["pa-alpha", "pa-gamma", "pa-delta", "pa-epsilon"]
        )

      assert length(updated_configs) == 4
      # Verify the one with pa- prefix was not changed
      assert Repo.get_by(TrackerScriptConfiguration, id: "pa-beta")
    end

    test "is idempotent - can be run multiple times safely" do
      _config = create_tracker_config("alpha")

      # Run migration first time
      output1 =
        capture_io(fn ->
          assert :ok = PrefixTrackerScriptConfigurationId.run(2)
        end)

      assert output1 =~ "Found 1 total tracker configurations to process"
      assert output1 =~ "Processing batch 1 (1-1 of 1)"

      # Run migration second time
      output2 =
        capture_io(fn ->
          assert :ok = PrefixTrackerScriptConfigurationId.run(2)
        end)

      assert output2 =~ "Found 0 total tracker configurations to process"
      assert output2 =~ "Migration completed!"

      # Verify configuration still has the prefix
      assert Repo.get_by(TrackerScriptConfiguration, id: "pa-alpha")
    end
  end

  describe "fails gracefully" do
    setup do
      add_constraint()
      :ok
    end

    test "handles database errors gracefully" do
      _config1 = create_tracker_config("alpha")
      _config2 = create_tracker_config("beta")

      output =
        capture_io(fn ->
          assert :ok = PrefixTrackerScriptConfigurationId.run(1)
        end)

      # Should still complete without crashing
      assert output =~ "Found 2 total tracker configurations to process"
      assert output =~ "Processing batch 1 (1-1 of 2)"
      assert output =~ "Error updating batch 1: "
      assert output =~ "Processing batch 2 (2-2 of 2)"
      assert output =~ "Migration completed!"
    end
  end

  # Helper function to create tracker configurations with specific IDs
  defp create_tracker_config(id) do
    site = new_site()

    # Use Repo.insert_all to bypass the autogenerate and set a specific ID
    Repo.insert_all(
      TrackerScriptConfiguration,
      [
        %{
          id: id,
          site_id: site.id,
          installation_type: :manual,
          track_404_pages: false,
          hash_based_routing: false,
          outbound_links: false,
          file_downloads: false,
          revenue_tracking: false,
          tagged_events: false,
          form_submissions: false,
          pageview_props: false,
          inserted_at: NaiveDateTime.utc_now(:second),
          updated_at: NaiveDateTime.utc_now(:second)
        }
      ]
    )

    Repo.get_by(TrackerScriptConfiguration, id: id)
  end

  defp add_constraint() do
    Repo.query!(
      "ALTER TABLE tracker_script_configuration ADD CONSTRAINT prevent_pa_prefix CHECK (id NOT LIKE 'pa-%')"
    )
  end

  defp remove_constraint_if_exists() do
    Repo.query!(
      "ALTER TABLE tracker_script_configuration DROP CONSTRAINT IF EXISTS prevent_pa_prefix"
    )
  end
end
