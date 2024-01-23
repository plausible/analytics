defmodule Plausible.Workers.ImportAnalyticsTest do
  use Plausible.DataCase
  use Bamboo.Test

  alias Plausible.Workers.ImportAnalytics

  @moduletag capture_log: true

  describe "Universal Analytics" do
    setup do
      %{
        imported_data: %Plausible.Site.ImportedData{
          start_date: Timex.today() |> Timex.shift(days: -7),
          end_date: Timex.today(),
          source: "Noop",
          status: "importing"
        }
      }
    end

    test "updates the imported_data field for the site after successful import", %{
      imported_data: imported_data
    } do
      user = insert(:user, trial_expiry_date: Timex.today() |> Timex.shift(days: 1))
      site = insert(:site, members: [user], imported_data: imported_data)

      ImportAnalytics.perform(%Oban.Job{
        args: %{
          "source" => "Noop",
          "site_id" => site.id
        }
      })

      assert Repo.reload!(site).imported_data.status == "ok"
    end

    test "updates the stats_start_date field for the site after successful import", %{
      imported_data: imported_data
    } do
      user = insert(:user, trial_expiry_date: Timex.today() |> Timex.shift(days: 1))
      site = insert(:site, members: [user], imported_data: imported_data)

      ImportAnalytics.perform(%Oban.Job{
        args: %{
          "source" => "Noop",
          "site_id" => site.id
        }
      })

      assert Repo.reload!(site).stats_start_date == imported_data.start_date
    end

    test "sends email to owner after successful import", %{imported_data: imported_data} do
      user = insert(:user, trial_expiry_date: Timex.today() |> Timex.shift(days: 1))
      site = insert(:site, members: [user], imported_data: imported_data)

      ImportAnalytics.perform(%Oban.Job{
        args: %{
          "source" => "Noop",
          "site_id" => site.id
        }
      })

      assert_email_delivered_with(
        to: [user],
        subject: "Noop data imported for #{site.domain}"
      )
    end

    test "updates site record after failed import", %{imported_data: imported_data} do
      user = insert(:user, trial_expiry_date: Timex.today() |> Timex.shift(days: 1))
      site = insert(:site, members: [user], imported_data: imported_data)

      ImportAnalytics.perform(%Oban.Job{
        args: %{
          "source" => "Noop",
          "site_id" => site.id,
          "error" => true
        }
      })

      assert Repo.reload!(site).imported_data.status == "error"
    end

    test "clears any orphaned data during import", %{imported_data: imported_data} do
      user = insert(:user, trial_expiry_date: Timex.today() |> Timex.shift(days: 1))
      site = insert(:site, members: [user], imported_data: imported_data)

      populate_stats(site, [
        build(:imported_visitors, pageviews: 10)
      ])

      ImportAnalytics.perform(%Oban.Job{
        args: %{
          "source" => "Noop",
          "site_id" => site.id,
          "error" => true
        }
      })

      assert eventually(fn ->
               count = Plausible.Stats.Clickhouse.imported_pageview_count(site)
               {count == 0, count}
             end)
    end

    test "sends email to owner after failed import", %{imported_data: imported_data} do
      user = insert(:user, trial_expiry_date: Timex.today() |> Timex.shift(days: 1))
      site = insert(:site, members: [user], imported_data: imported_data)

      ImportAnalytics.perform(%Oban.Job{
        args: %{
          "source" => "Noop",
          "site_id" => site.id,
          "error" => true
        }
      })

      assert_email_delivered_with(
        to: [user],
        subject: "Noop import failed for #{site.domain}"
      )
    end
  end
end
