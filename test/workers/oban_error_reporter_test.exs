defmodule ObanErrorReporterTest do
  use Plausible.DataCase
  use Bamboo.Test
  import ExUnit.CaptureLog

  require Plausible.Imported.SiteImport

  describe "handle_event/4" do
    setup do
      :telemetry.attach_many(
        "oban-errors-test",
        [[:oban, :job, :exception], [:oban, :notifier, :exception], [:oban, :plugin, :exception]],
        &ObanErrorReporter.handle_event/4,
        %{}
      )

      on_exit(fn -> :ok = :telemetry.detach("oban-errors-test") end)
    end

    @tag :capture_log
    test "doesn't detach on failure" do
      :ok =
        :telemetry.execute(
          [:oban, :job, :exception],
          _bad_measurements = %{},
          _bad_metadata = %{job: :bad_job}
        )

      handlers = :telemetry.list_handlers([:oban, :job, :exception])
      assert Enum.any?(handlers, &(&1.id == "oban-errors-test"))
    end

    test "logs an error on failure" do
      log =
        capture_log(fn ->
          :ok =
            :telemetry.execute(
              [:oban, :job, :exception],
              _bad_measurements = %{},
              _bad_metadata = %{job: :bad_job}
            )
        end)

      assert log =~ "(BadMapError)"
      assert log =~ ":bad_job"
    end
  end

  describe "on_job_exception/1 import failure handling" do
    setup do
      user = new_user()
      site = new_site(owner: user)

      site_import =
        insert(:site_import,
          site: site,
          imported_by: user,
          status: Plausible.Imported.SiteImport.completed()
        )

      populate_stats(site, site_import.id, [build(:imported_visitors)])

      {:ok, site: site, site_import: site_import, user: user}
    end

    test "ImportAnalytics exception purges imported stats on transient failure", %{
      site_import: site_import
    } do
      query = from(v in Plausible.Imported.Visitor, where: v.import_id == ^site_import.id)
      assert await_clickhouse_count(query, 1)

      capture_log(fn ->
        ObanErrorReporter.handle_event(
          [:oban, :job, :exception],
          %{},
          exception_meta(
            worker: "Plausible.Workers.ImportAnalytics",
            import_id: site_import.id,
            attempt: 1,
            max_attempts: 3
          ),
          nil
        )
      end)

      assert await_clickhouse_count(query, 0)

      site_import = Repo.reload!(site_import)
      assert site_import.status == Plausible.Imported.SiteImport.completed()
      assert_no_emails_delivered()
    end

    test "ImportAnalytics exception marks import failed on final attempt", %{
      site_import: site_import,
      user: user,
      site: site
    } do
      capture_log(fn ->
        ObanErrorReporter.handle_event(
          [:oban, :job, :exception],
          %{},
          exception_meta(
            worker: "Plausible.Workers.ImportAnalytics",
            import_id: site_import.id,
            attempt: 3,
            max_attempts: 3
          ),
          nil
        )
      end)

      site_import = Repo.reload!(site_import)
      assert site_import.status == Plausible.Imported.SiteImport.failed()

      assert_email_delivered_with(
        to: [user],
        subject: "Google Analytics import failed for #{site.domain}"
      )
    end

    test "LocalImportAnalyticsCleaner exception does not purge stats or mark import failed", %{
      site_import: site_import
    } do
      query = from(v in Plausible.Imported.Visitor, where: v.import_id == ^site_import.id)
      assert await_clickhouse_count(query, 1)

      capture_log(fn ->
        ObanErrorReporter.handle_event(
          [:oban, :job, :exception],
          %{},
          exception_meta(
            worker: "Plausible.Workers.LocalImportAnalyticsCleaner",
            import_id: site_import.id,
            attempt: 1,
            max_attempts: 20,
            args: %{"import_id" => site_import.id, "paths" => ["/tmp/import.csv"]}
          ),
          nil
        )
      end)

      assert await_clickhouse_count(query, 1)

      site_import = Repo.reload!(site_import)
      assert site_import.status == Plausible.Imported.SiteImport.completed()
      assert_no_emails_delivered()
    end

    test "LocalImportAnalyticsCleaner final attempt does not mark import failed", %{
      site_import: site_import
    } do
      capture_log(fn ->
        ObanErrorReporter.handle_event(
          [:oban, :job, :exception],
          %{},
          exception_meta(
            worker: "Plausible.Workers.LocalImportAnalyticsCleaner",
            import_id: site_import.id,
            attempt: 20,
            max_attempts: 20,
            args: %{"import_id" => site_import.id, "paths" => ["/tmp/import.csv"]}
          ),
          nil
        )
      end)

      site_import = Repo.reload!(site_import)
      assert site_import.status == Plausible.Imported.SiteImport.completed()
      assert_no_emails_delivered()
    end
  end

  defp exception_meta(opts) do
    import_id = Keyword.fetch!(opts, :import_id)
    worker = Keyword.fetch!(opts, :worker)
    attempt = Keyword.fetch!(opts, :attempt)
    max_attempts = Keyword.fetch!(opts, :max_attempts)
    args = Keyword.get(opts, :args, %{"import_id" => import_id})

    %{
      job: %Oban.Job{
        queue: "analytics_imports",
        worker: worker,
        args: args,
        state: "executing",
        attempt: attempt,
        max_attempts: max_attempts
      },
      reason: %RuntimeError{message: "boom"},
      stacktrace: []
    }
  end
end
