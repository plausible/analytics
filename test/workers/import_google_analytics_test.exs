defmodule Plausible.Workers.ImportGoogleAnalyticsTest do
  use Plausible.DataCase
  use Bamboo.Test
  import Double

  alias Plausible.Workers.ImportGoogleAnalytics

  @imported_data %Plausible.Site.ImportedData{
    start_date: Timex.today() |> Timex.shift(days: -7),
    end_date: Timex.today(),
    source: "Google Analytics",
    status: "importing"
  }

  test "updates the imported_data field for the site after successful import" do
    user = insert(:user, trial_expiry_date: Timex.today() |> Timex.shift(days: 1))
    site = insert(:site, members: [user], imported_data: @imported_data)

    api_stub =
      stub(Plausible.Google.Api, :import_analytics, fn _site,
                                                       _date_range,
                                                       _view_id,
                                                       _access_token ->
        :ok
      end)

    ImportGoogleAnalytics.perform(
      %Oban.Job{
        args: %{
          "site_id" => site.id,
          "view_id" => "view_id",
          "start_date" => "2020-01-01",
          "end_date" => "2022-01-01",
          "access_token" => "token"
        }
      },
      api_stub
    )

    assert Repo.reload!(site).imported_data.status == "ok"
  end

  test "updates the stats_start_date field for the site after successful import" do
    user = insert(:user, trial_expiry_date: Timex.today() |> Timex.shift(days: 1))
    site = insert(:site, members: [user], imported_data: @imported_data)

    api_stub =
      stub(Plausible.Google.Api, :import_analytics, fn _site,
                                                       _date_range,
                                                       _view_id,
                                                       _access_token ->
        :ok
      end)

    ImportGoogleAnalytics.perform(
      %Oban.Job{
        args: %{
          "site_id" => site.id,
          "view_id" => "view_id",
          "start_date" => "2020-01-01",
          "end_date" => "2022-01-01",
          "access_token" => "token"
        }
      },
      api_stub
    )

    assert Repo.reload!(site).stats_start_date == @imported_data.start_date
  end

  test "sends email to owner after successful import" do
    user = insert(:user, trial_expiry_date: Timex.today() |> Timex.shift(days: 1))
    site = insert(:site, members: [user], imported_data: @imported_data)

    api_stub =
      stub(Plausible.Google.Api, :import_analytics, fn _site,
                                                       _date_range,
                                                       _view_id,
                                                       _access_token ->
        :ok
      end)

    ImportGoogleAnalytics.perform(
      %Oban.Job{
        args: %{
          "site_id" => site.id,
          "view_id" => "view_id",
          "start_date" => "2020-01-01",
          "end_date" => "2022-01-01",
          "access_token" => "token"
        }
      },
      api_stub
    )

    assert_email_delivered_with(
      to: [user],
      subject: "Google Analytics data imported for #{site.domain}"
    )
  end

  test "updates site record after failed import" do
    user = insert(:user, trial_expiry_date: Timex.today() |> Timex.shift(days: 1))
    site = insert(:site, members: [user], imported_data: @imported_data)

    api_stub =
      stub(Plausible.Google.Api, :import_analytics, fn _site,
                                                       _date_range,
                                                       _view_id,
                                                       _access_token ->
        {:error, "Something went wrong"}
      end)

    ImportGoogleAnalytics.perform(
      %Oban.Job{
        args: %{
          "site_id" => site.id,
          "view_id" => "view_id",
          "start_date" => "2020-01-01",
          "end_date" => "2022-01-01",
          "access_token" => "token"
        }
      },
      api_stub
    )

    assert Repo.reload!(site).imported_data.status == "error"
  end

  test "clears any orphaned data during import" do
    user = insert(:user, trial_expiry_date: Timex.today() |> Timex.shift(days: 1))
    site = insert(:site, members: [user], imported_data: @imported_data)

    populate_stats(site, [
      build(:imported_visitors, pageviews: 10)
    ])

    api_stub =
      stub(Plausible.Google.Api, :import_analytics, fn _site,
                                                       _date_range,
                                                       _view_id,
                                                       _access_token ->
        {:error, "Something went wrong"}
      end)

    ImportGoogleAnalytics.perform(
      %Oban.Job{
        args: %{
          "site_id" => site.id,
          "view_id" => "view_id",
          "start_date" => "2020-01-01",
          "end_date" => "2022-01-01",
          "access_token" => "token"
        }
      },
      api_stub
    )

    assert Plausible.Stats.Clickhouse.imported_pageview_count(site) == 0
  end

  test "sends email to owner after failed import" do
    user = insert(:user, trial_expiry_date: Timex.today() |> Timex.shift(days: 1))
    site = insert(:site, members: [user], imported_data: @imported_data)

    api_stub =
      stub(Plausible.Google.Api, :import_analytics, fn _site,
                                                       _date_range,
                                                       _view_id,
                                                       _access_token ->
        {:error, "Something went wrong"}
      end)

    ImportGoogleAnalytics.perform(
      %Oban.Job{
        args: %{
          "site_id" => site.id,
          "view_id" => "view_id",
          "start_date" => "2020-01-01",
          "end_date" => "2022-01-01",
          "access_token" => "token"
        }
      },
      api_stub
    )

    assert_email_delivered_with(
      to: [user],
      subject: "Google Analytics import failed for #{site.domain}"
    )
  end
end
