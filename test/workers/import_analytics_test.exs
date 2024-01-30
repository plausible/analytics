defmodule Plausible.Workers.ImportAnalyticsTest do
  use Plausible.DataCase
  use Bamboo.Test

  alias Plausible.Workers.ImportAnalytics

  @moduletag capture_log: true

  describe "perform/1" do
    setup do
      %{
        import_opts: [
          start_date: Timex.today() |> Timex.shift(days: -7),
          end_date: Timex.today()
        ]
      }
    end

    test "updates site import after successful import", %{
      import_opts: import_opts
    } do
      user = insert(:user, trial_expiry_date: Timex.today() |> Timex.shift(days: 1))
      site = insert(:site, members: [user])

      {:ok, job} = Plausible.Imported.NoopImporter.new_import(site, user, import_opts)

      assert [%{status: :pending}] = Plausible.Imported.list_all_imports(site)

      # before_start callback triggered
      assert_received {:before_start, import_id}

      job
      |> Repo.reload!()
      |> ImportAnalytics.perform()

      assert [%{id: ^import_id, status: :completed}] = Plausible.Imported.list_all_imports(site)

      # on_success callback triggered
      assert_received {:on_success, ^import_id}
    end

    test "clears stats_start_date field for the site after successful import", %{
      import_opts: import_opts
    } do
      user = insert(:user, trial_expiry_date: Timex.today() |> Timex.shift(days: 1))
      site = insert(:site, members: [user], stats_start_date: ~D[2005-01-01])

      {:ok, job} = Plausible.Imported.NoopImporter.new_import(site, user, import_opts)

      job
      |> Repo.reload!()
      |> ImportAnalytics.perform()

      site = Repo.reload!(site)
      assert site.stats_start_date == nil
      assert Plausible.Sites.stats_start_date(site) == import_opts[:start_date]
      assert Repo.reload!(site).stats_start_date == import_opts[:start_date]
    end

    test "sends email to owner after successful import", %{import_opts: import_opts} do
      user = insert(:user, trial_expiry_date: Timex.today() |> Timex.shift(days: 1))
      site = insert(:site, members: [user])

      {:ok, job} = Plausible.Imported.NoopImporter.new_import(site, user, import_opts)

      job
      |> Repo.reload!()
      |> ImportAnalytics.perform()

      assert_email_delivered_with(
        to: [user],
        subject: "Noop data imported for #{site.domain}"
      )
    end

    test "updates site import record after failed import", %{import_opts: import_opts} do
      user = insert(:user, trial_expiry_date: Timex.today() |> Timex.shift(days: 1))
      site = insert(:site, members: [user])
      import_opts = Keyword.put(import_opts, :error, true)

      {:ok, job} = Plausible.Imported.NoopImporter.new_import(site, user, import_opts)

      job
      |> Repo.reload!()
      |> ImportAnalytics.perform()

      assert [%{status: :failed}] = Plausible.Imported.list_all_imports(site)
    end

    test "clears any orphaned data during import", %{import_opts: import_opts} do
      user = insert(:user, trial_expiry_date: Timex.today() |> Timex.shift(days: 1))
      site = insert(:site, members: [user])
      import_opts = Keyword.put(import_opts, :error, true)

      {:ok, job} = Plausible.Imported.NoopImporter.new_import(site, user, import_opts)

      populate_stats(site, [
        build(:imported_visitors, import_id: job.args.import_id, pageviews: 10)
      ])

      job
      |> Repo.reload!()
      |> ImportAnalytics.perform()

      assert eventually(fn ->
               count = Plausible.Stats.Clickhouse.imported_pageview_count(site)
               {count == 0, count}
             end)

      # on_failure callback triggered
      assert_received {:on_failure, _import_id}
    end

    test "sends email to owner after failed import", %{import_opts: import_opts} do
      user = insert(:user, trial_expiry_date: Timex.today() |> Timex.shift(days: 1))
      site = insert(:site, members: [user])
      import_opts = Keyword.put(import_opts, :error, true)

      {:ok, job} = Plausible.Imported.NoopImporter.new_import(site, user, import_opts)

      job
      |> Repo.reload!()
      |> ImportAnalytics.perform()

      assert_email_delivered_with(
        to: [user],
        subject: "Noop import failed for #{site.domain}"
      )
    end
  end
end
