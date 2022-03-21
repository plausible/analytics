defmodule Plausible.Workers.ImportGoogleAnalyticsTest do
  use Plausible.DataCase
  use Bamboo.Test
  import Double
  alias Plausible.Workers.ImportGoogleAnalytics

  @imported_data %Plausible.Site.ImportedData{
    end_date: Timex.today(),
    source: "Google Analytics",
    status: "importing"
  }

  test "updates the imported_data field for the site after succesful import" do
    user = insert(:user, trial_expiry_date: Timex.today() |> Timex.shift(days: 1))
    site = insert(:site, members: [user], imported_data: @imported_data)

    api_stub =
      stub(Plausible.Google.Api, :import_analytics, fn _site, _view_id, _end_date ->
        {:ok, nil}
      end)

    ImportGoogleAnalytics.perform(
      %Oban.Job{
        args: %{"site_id" => site.id, "view_id" => "view_id", "end_date" => "2022-01-01"}
      },
      api_stub
    )

    assert Repo.reload!(site).imported_data.status == "ok"
  end

  test "sends email to owner after succesful import" do
    user = insert(:user, trial_expiry_date: Timex.today() |> Timex.shift(days: 1))
    site = insert(:site, members: [user], imported_data: @imported_data)

    api_stub =
      stub(Plausible.Google.Api, :import_analytics, fn _site, _view_id, _end_date ->
        {:ok, nil}
      end)

    ImportGoogleAnalytics.perform(
      %Oban.Job{
        args: %{"site_id" => site.id, "view_id" => "view_id", "end_date" => "2022-01-01"}
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
      stub(Plausible.Google.Api, :import_analytics, fn _site, _view_id, _end_date ->
        {:error, "Something went wrong"}
      end)

    ImportGoogleAnalytics.perform(
      %Oban.Job{
        args: %{"site_id" => site.id, "view_id" => "view_id", "end_date" => "2022-01-01"}
      },
      api_stub
    )

    assert Repo.reload!(site).imported_data.status == "error"
  end

  test "sends email to owner after failed import" do
    user = insert(:user, trial_expiry_date: Timex.today() |> Timex.shift(days: 1))
    site = insert(:site, members: [user], imported_data: @imported_data)

    api_stub =
      stub(Plausible.Google.Api, :import_analytics, fn _site, _view_id, _end_date ->
        {:error, "Something went wrong"}
      end)

    ImportGoogleAnalytics.perform(
      %Oban.Job{
        args: %{"site_id" => site.id, "view_id" => "view_id", "end_date" => "2022-01-01"}
      },
      api_stub
    )

    assert_email_delivered_with(
      to: [user],
      subject: "Google Analytics import failed for #{site.domain}"
    )
  end
end
