defmodule Plausible.Workers.NotifyExportedAnalyticsTest do
  use Plausible
  use Plausible.DataCase
  use Plausible.Teams.Test
  use Bamboo.Test

  describe "perform/1" do
    setup do
      user = new_user()
      site = new_site(owner: user)
      {:ok, user: user, site: site}
    end

    # for 'success' case please see Plausible.Imported.CSVImporterTest
    test "delivers 'failure' email", %{user: user, site: site} do
      job =
        Plausible.Workers.NotifyExportedAnalytics.new(%{
          "status" => "failure",
          "storage" => on_ee(do: "s3", else: "local"),
          "email_to" => user.email,
          "site_id" => site.id
        })

      Oban.insert!(job)

      assert %{success: 1} =
               Oban.drain_queue(queue: :notify_exported_analytics, with_safety: false)

      assert_receive {:delivered_email, email}
      assert email.html_body =~ "was unsuccessful."
    end
  end
end
