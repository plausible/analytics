defmodule Plausible.Workers.LocalImportAnalyticsCleanerTest do
  use Plausible.DataCase, async: true
  import ExUnit.CaptureLog

  alias Plausible.Workers.LocalImportAnalyticsCleaner
  alias Plausible.Imported.SiteImport

  require SiteImport

  describe "perform/1" do
    test "deletes local import files when import is no longer in progress" do
      site_import = insert(:site_import, status: SiteImport.completed())
      {dir, path} = writable_import_file!()

      assert :ok =
               LocalImportAnalyticsCleaner.perform(%Oban.Job{
                 args: %{"import_id" => site_import.id, "paths" => [path]},
                 attempt: 1,
                 max_attempts: 20
               })

      refute File.exists?(path)
      File.rm_rf!(dir)
    end

    test "snoozes when import is still in progress" do
      site_import = insert(:site_import, status: SiteImport.importing())
      {dir, path} = writable_import_file!()

      assert {:snooze, 3600} =
               LocalImportAnalyticsCleaner.perform(%Oban.Job{
                 args: %{"import_id" => site_import.id, "paths" => [path]},
                 attempt: 1,
                 max_attempts: 20
               })

      assert File.exists?(path)
      File.rm_rf!(dir)
    end

    test "logs when a leftover file cannot be deleted on the final attempt" do
      site_import = insert(:site_import, status: SiteImport.completed())
      {dir, path} = undeletable_import_file!()

      log =
        capture_log(fn ->
          assert_raise File.Error, fn ->
            LocalImportAnalyticsCleaner.perform(%Oban.Job{
              args: %{"import_id" => site_import.id, "paths" => [path]},
              attempt: 20,
              max_attempts: 20
            })
          end
        end)

      assert log =~
               "Failed to delete leftover local import file #{path} for import_id=#{site_import.id}"

      assert File.exists?(path)
      File.chmod!(dir, 0o755)
      File.rm_rf!(dir)
    end

    test "does not log undeleted files before the final attempt" do
      site_import = insert(:site_import, status: SiteImport.completed())
      {dir, path} = undeletable_import_file!()

      log =
        capture_log(fn ->
          assert_raise File.Error, fn ->
            LocalImportAnalyticsCleaner.perform(%Oban.Job{
              args: %{"import_id" => site_import.id, "paths" => [path]},
              attempt: 1,
              max_attempts: 20
            })
          end
        end)

      refute log =~ "Failed to delete leftover local import file"

      assert File.exists?(path)
      File.chmod!(dir, 0o755)
      File.rm_rf!(dir)
    end
  end

  defp writable_import_file! do
    dir =
      Path.join(System.tmp_dir!(), "plausible-import-cleaner-#{System.unique_integer([:positive])}")

    File.mkdir_p!(dir)
    path = Path.join(dir, "imported_visitors_20240101_20240131.csv")
    File.write!(path, "date,visitors\n2024-01-01,1\n")
    {dir, path}
  end

  defp undeletable_import_file! do
    {dir, path} = writable_import_file!()
    # Deleting a file requires write permission on the parent directory.
    File.chmod!(dir, 0o555)
    {dir, path}
  end
end
