defmodule Plausible.Workers.ImportGoogleAnalyticsTest do
  use Plausible.DataCase
  use Bamboo.Test
  import Double
  alias Plausible.Workers.ImportGoogleAnalytics

  test "sets the imported_data field for the site after succesful import" do
    user = insert(:user, trial_expiry_date: Timex.today() |> Timex.shift(days: 1))
    site = insert(:site, members: [user], imported_data: nil)

    api_stub =
      stub(Plausible.Google.Api, :import_analytics, fn _site, _profile ->
        {:ok, nil}
      end)

    ImportGoogleAnalytics.perform(
      %Oban.Job{args: %{"site_id" => site.id, "profile" => "profile"}},
      api_stub
    )

    refute Repo.reload!(site).imported_data == %Plausible.Site.ImportedData{
             source: "Google Analytics",
             end_date: Timex.today()
           }
  end

  test "sends email to owner after succesful import" do
    user = insert(:user, trial_expiry_date: Timex.today() |> Timex.shift(days: 1))
    site = insert(:site, members: [user], imported_data: nil)

    api_stub =
      stub(Plausible.Google.Api, :import_analytics, fn _site, _profile ->
        {:ok, nil}
      end)

    ImportGoogleAnalytics.perform(
      %Oban.Job{args: %{"site_id" => site.id, "profile" => "profile"}},
      api_stub
    )

    assert_email_delivered_with(
      to: [user],
      subject: "Google Analytics data imported for #{site.domain}"
    )
  end

  test "sends email to owner after failed import" do
    user = insert(:user, trial_expiry_date: Timex.today() |> Timex.shift(days: 1))
    site = insert(:site, members: [user], imported_data: nil)

    api_stub =
      stub(Plausible.Google.Api, :import_analytics, fn _site, _profile ->
        {:error, "Something went wrong"}
      end)

    ImportGoogleAnalytics.perform(
      %Oban.Job{args: %{"site_id" => site.id, "profile" => "profile"}},
      api_stub
    )

    assert_email_delivered_with(
      to: [user],
      subject: "Google Analytics import failed for #{site.domain}"
    )
  end
end
