defmodule PlausibleWeb.SiteControllerTest do
  use PlausibleWeb.ConnCase
  use Plausible.Repo
  use Bamboo.Test
  use Oban.Testing, repo: Plausible.Repo
  import Plausible.TestUtils

  describe "GET /sites/new" do
    setup [:create_user, :log_in]

    test "shows the site form", %{conn: conn} do
      conn = get(conn, "/sites/new")

      assert html_response(conn, 200) =~ "Your website details"
    end

    test "shows onboarding steps if it's the first site for the user", %{conn: conn} do
      conn = get(conn, "/sites/new")

      assert html_response(conn, 200) =~ "Add site info"
    end

    test "does not show onboarding steps if user has a site already", %{conn: conn, user: user} do
      insert(:site, members: [user], domain: "test-site.com")

      conn = get(conn, "/sites/new")

      refute html_response(conn, 200) =~ "Add site info"
    end
  end

  describe "GET /sites" do
    setup [:create_user, :log_in]

    test "shows empty screen if no sites", %{conn: conn} do
      conn = get(conn, "/sites")
      assert html_response(conn, 200) =~ "You don't have any sites yet"
    end

    test "lists all of your sites with last 24h visitors", %{conn: conn, user: user} do
      insert(:site, members: [user], domain: "test-site.com")
      conn = get(conn, "/sites")

      assert html_response(conn, 200) =~ "test-site.com"
      assert html_response(conn, 200) =~ "<b>3</b> visitors in last 24h"
    end

    test "shows invitations for user by email address", %{conn: conn, user: user} do
      site = insert(:site)
      insert(:invitation, email: user.email, site_id: site.id, inviter: build(:user))
      conn = get(conn, "/sites")

      assert html_response(conn, 200) =~ site.domain
    end

    test "invitations are case insensitive", %{conn: conn, user: user} do
      site = insert(:site)

      insert(:invitation,
        email: String.upcase(user.email),
        site_id: site.id,
        inviter: build(:user)
      )

      conn = get(conn, "/sites")

      assert html_response(conn, 200) =~ site.domain
    end

    test "paginates sites", %{conn: conn, user: user} do
      insert(:site, members: [user], domain: "test-site1.com")
      insert(:site, members: [user], domain: "test-site2.com")
      insert(:site, members: [user], domain: "test-site3.com")
      insert(:site, members: [user], domain: "test-site4.com")

      conn = get(conn, "/sites?per_page=2")

      assert html_response(conn, 200) =~ "test-site1.com"
      assert html_response(conn, 200) =~ "test-site2.com"
      refute html_response(conn, 200) =~ "test-site3.com"
      refute html_response(conn, 200) =~ "test-site4.com"

      conn = get(conn, "/sites?per_page=2&page=2")

      refute html_response(conn, 200) =~ "test-site1.com"
      refute html_response(conn, 200) =~ "test-site2.com"
      assert html_response(conn, 200) =~ "test-site3.com"
      assert html_response(conn, 200) =~ "test-site4.com"
    end
  end

  describe "POST /sites" do
    setup [:create_user, :log_in]

    test "creates the site with valid params", %{conn: conn} do
      conn =
        post(conn, "/sites", %{
          "site" => %{
            "domain" => "example.com",
            "timezone" => "Europe/London"
          }
        })

      assert redirected_to(conn) == "/example.com/snippet"
      assert Repo.exists?(Plausible.Site, domain: "example.com")
    end

    test "starts trial if user does not have trial yet", %{conn: conn, user: user} do
      Plausible.Auth.User.remove_trial_expiry(user) |> Repo.update!()

      post(conn, "/sites", %{
        "site" => %{
          "domain" => "example.com",
          "timezone" => "Europe/London"
        }
      })

      assert Repo.reload!(user).trial_expiry_date
    end

    test "sends welcome email if this is the user's first site", %{conn: conn} do
      post(conn, "/sites", %{
        "site" => %{
          "domain" => "example.com",
          "timezone" => "Europe/London"
        }
      })

      assert_email_delivered_with(subject: "Welcome to Plausible")
    end

    test "does not send welcome email if user already has a previous site", %{
      conn: conn,
      user: user
    } do
      insert(:site, members: [user])

      post(conn, "/sites", %{
        "site" => %{
          "domain" => "example.com",
          "timezone" => "Europe/London"
        }
      })

      assert_no_emails_delivered()
    end

    test "does not allow site creation when the user is at their site limit", %{
      conn: conn,
      user: user
    } do
      # default site limit defined in config/.test.env
      insert(:site, members: [user])
      insert(:site, members: [user])
      insert(:site, members: [user])

      conn =
        post(conn, "/sites", %{
          "site" => %{
            "domain" => "example.com",
            "timezone" => "Europe/London"
          }
        })

      assert conn.status == 400
    end

    test "allows accounts registered before 2021-05-05 to go over the limit", %{
      conn: conn,
      user: user
    } do
      Repo.update_all(from(u in "users", where: u.id == ^user.id),
        set: [inserted_at: ~N[2020-01-01 00:00:00]]
      )

      insert(:site, members: [user])
      insert(:site, members: [user])
      insert(:site, members: [user])
      insert(:site, members: [user])

      conn =
        post(conn, "/sites", %{
          "site" => %{
            "domain" => "example.com",
            "timezone" => "Europe/London"
          }
        })

      assert redirected_to(conn) == "/example.com/snippet"
      assert Repo.exists?(Plausible.Site, domain: "example.com")
    end

    test "allows enterprise accounts to create unlimited sites", %{
      conn: conn,
      user: user
    } do
      insert(:enterprise_plan, user: user)

      insert(:site, members: [user])
      insert(:site, members: [user])
      insert(:site, members: [user])

      conn =
        post(conn, "/sites", %{
          "site" => %{
            "domain" => "example.com",
            "timezone" => "Europe/London"
          }
        })

      assert redirected_to(conn) == "/example.com/snippet"
      assert Repo.exists?(Plausible.Site, domain: "example.com")
    end

    test "cleans up the url", %{conn: conn} do
      conn =
        post(conn, "/sites", %{
          "site" => %{
            "domain" => "https://www.Example.com/",
            "timezone" => "Europe/London"
          }
        })

      assert redirected_to(conn) == "/example.com/snippet"
      assert Repo.exists?(Plausible.Site, domain: "example.com")
    end

    test "renders form again when domain is missing", %{conn: conn} do
      conn =
        post(conn, "/sites", %{
          "site" => %{
            "timezone" => "Europe/London"
          }
        })

      assert html_response(conn, 200) =~ "can&#39;t be blank"
    end

    test "only alphanumeric characters and slash allowed in domain", %{conn: conn} do
      conn =
        post(conn, "/sites", %{
          "site" => %{
            "timezone" => "Europe/London",
            "domain" => "!@£.com"
          }
        })

      assert html_response(conn, 200) =~ "only letters, numbers, slashes and period allowed"
    end

    test "renders form again when it is a duplicate domain", %{conn: conn} do
      insert(:site, domain: "example.com")

      conn =
        post(conn, "/sites", %{
          "site" => %{
            "domain" => "example.com",
            "timezone" => "Europe/London"
          }
        })

      assert html_response(conn, 200) =~
               "This domain has already been taken. Perhaps one of your team members registered it? If that&#39;s not the case, please contact support@plausible.io"
    end
  end

  describe "GET /:website/snippet" do
    setup [:create_user, :log_in, :create_site]

    test "shows snippet", %{conn: conn, site: site} do
      conn = get(conn, "/#{site.domain}/snippet")

      assert html_response(conn, 200) =~ "Add javascript snippet"
    end
  end

  describe "GET /:website/settings/general" do
    setup [:create_user, :log_in, :create_site]

    test "shows settings form", %{conn: conn, site: site} do
      conn = get(conn, "/#{site.domain}/settings/general")

      assert html_response(conn, 200) =~ "General information"
    end
  end

  describe "GET /:website/settings/goals" do
    setup [:create_user, :log_in, :create_site]

    test "lists goals for the site", %{conn: conn, site: site} do
      insert(:goal, domain: site.domain, event_name: "Custom event")
      insert(:goal, domain: site.domain, page_path: "/register")

      conn = get(conn, "/#{site.domain}/settings/goals")

      assert html_response(conn, 200) =~ "Custom event"
      assert html_response(conn, 200) =~ "Visit /register"
    end
  end

  describe "PUT /:website/settings" do
    setup [:create_user, :log_in, :create_site]

    test "updates the timezone", %{conn: conn, site: site} do
      conn =
        put(conn, "/#{site.domain}/settings", %{
          "site" => %{
            "timezone" => "Europe/London"
          }
        })

      updated = Repo.get(Plausible.Site, site.id)
      assert updated.timezone == "Europe/London"
      assert redirected_to(conn, 302) == "/#{site.domain}/settings/general"
    end
  end

  describe "POST /sites/:website/make-public" do
    setup [:create_user, :log_in, :create_site]

    test "makes the site public", %{conn: conn, site: site} do
      conn = post(conn, "/sites/#{site.domain}/make-public")

      updated = Repo.get(Plausible.Site, site.id)
      assert updated.public
      assert redirected_to(conn, 302) == "/#{site.domain}/settings/visibility"
    end
  end

  describe "POST /sites/:website/make-private" do
    setup [:create_user, :log_in, :create_site]

    test "makes the site private", %{conn: conn, site: site} do
      conn = post(conn, "/sites/#{site.domain}/make-private")

      updated = Repo.get(Plausible.Site, site.id)
      refute updated.public
      assert redirected_to(conn, 302) == "/#{site.domain}/settings/visibility"
    end
  end

  describe "DELETE /:website" do
    setup [:create_user, :log_in, :create_site]

    test "deletes the site", %{conn: conn, user: user} do
      site = insert(:site, members: [user])
      insert(:google_auth, user: user, site: site)
      insert(:custom_domain, site: site)
      insert(:spike_notification, site: site)

      delete(conn, "/#{site.domain}")

      refute Repo.exists?(from s in Plausible.Site, where: s.id == ^site.id)
    end
  end

  describe "PUT /:website/settings/google" do
    setup [:create_user, :log_in, :create_site]

    test "updates google auth property", %{conn: conn, user: user, site: site} do
      insert(:google_auth, user: user, site: site)

      conn =
        put(conn, "/#{site.domain}/settings/google", %{
          "google_auth" => %{"property" => "some-new-property.com"}
        })

      updated_auth = Repo.one(Plausible.Site.GoogleAuth)
      assert updated_auth.property == "some-new-property.com"
      assert redirected_to(conn, 302) == "/#{site.domain}/settings/search-console"
    end
  end

  describe "DELETE /:website/settings/google" do
    setup [:create_user, :log_in, :create_site]

    test "deletes associated google auth", %{conn: conn, user: user, site: site} do
      insert(:google_auth, user: user, site: site)
      conn = delete(conn, "/#{site.domain}/settings/google-search")

      refute Repo.exists?(Plausible.Site.GoogleAuth)
      assert redirected_to(conn, 302) == "/#{site.domain}/settings/search-console"
    end
  end

  describe "GET /:website/goals/new" do
    setup [:create_user, :log_in, :create_site]

    test "shows form to create a new goal", %{conn: conn, site: site} do
      conn = get(conn, "/#{site.domain}/goals/new")

      assert html_response(conn, 200) =~ "Add goal"
    end
  end

  describe "POST /:website/goals" do
    setup [:create_user, :log_in, :create_site]

    test "creates a pageview goal for the website", %{conn: conn, site: site} do
      conn =
        post(conn, "/#{site.domain}/goals", %{
          goal: %{
            page_path: "/success",
            event_name: ""
          }
        })

      goal = Repo.one(Plausible.Goal)

      assert goal.page_path == "/success"
      assert goal.event_name == nil
      assert redirected_to(conn, 302) == "/#{site.domain}/settings/goals"
    end

    test "creates a custom event goal for the website", %{conn: conn, site: site} do
      conn =
        post(conn, "/#{site.domain}/goals", %{
          goal: %{
            page_path: "",
            event_name: "Signup"
          }
        })

      goal = Repo.one(Plausible.Goal)

      assert goal.event_name == "Signup"
      assert goal.page_path == nil
      assert redirected_to(conn, 302) == "/#{site.domain}/settings/goals"
    end
  end

  describe "DELETE /:website/goals/:id" do
    setup [:create_user, :log_in, :create_site]

    test "lists goals for the site", %{conn: conn, site: site} do
      goal = insert(:goal, domain: site.domain, event_name: "Custom event")

      conn = delete(conn, "/#{site.domain}/goals/#{goal.id}")

      assert Repo.aggregate(Plausible.Goal, :count, :id) == 0
      assert redirected_to(conn, 302) == "/#{site.domain}/settings/goals"
    end
  end

  describe "POST /sites/:website/weekly-report/enable" do
    setup [:create_user, :log_in, :create_site]

    test "creates a weekly report record with the user email", %{
      conn: conn,
      site: site,
      user: user
    } do
      post(conn, "/sites/#{site.domain}/weekly-report/enable")

      report = Repo.get_by(Plausible.Site.WeeklyReport, site_id: site.id)
      assert report.recipients == [user.email]
    end
  end

  describe "POST /sites/:website/weekly-report/disable" do
    setup [:create_user, :log_in, :create_site]

    test "deletes the weekly report record", %{conn: conn, site: site} do
      insert(:weekly_report, site: site)

      post(conn, "/sites/#{site.domain}/weekly-report/disable")

      refute Repo.get_by(Plausible.Site.WeeklyReport, site_id: site.id)
    end
  end

  describe "POST /sites/:website/weekly-report/recipients" do
    setup [:create_user, :log_in, :create_site]

    test "adds a recipient to the weekly report", %{conn: conn, site: site} do
      insert(:weekly_report, site: site)

      post(conn, "/sites/#{site.domain}/weekly-report/recipients", recipient: "user@email.com")

      report = Repo.get_by(Plausible.Site.WeeklyReport, site_id: site.id)
      assert report.recipients == ["user@email.com"]
    end
  end

  describe "DELETE /sites/:website/weekly-report/recipients/:recipient" do
    setup [:create_user, :log_in, :create_site]

    test "removes a recipient from the weekly report", %{conn: conn, site: site} do
      insert(:weekly_report, site: site, recipients: ["recipient@email.com"])

      delete(conn, "/sites/#{site.domain}/weekly-report/recipients/recipient@email.com")

      report = Repo.get_by(Plausible.Site.WeeklyReport, site_id: site.id)
      assert report.recipients == []
    end
  end

  describe "POST /sites/:website/monthly-report/enable" do
    setup [:create_user, :log_in, :create_site]

    test "creates a monthly report record with the user email", %{
      conn: conn,
      site: site,
      user: user
    } do
      post(conn, "/sites/#{site.domain}/monthly-report/enable")

      report = Repo.get_by(Plausible.Site.MonthlyReport, site_id: site.id)
      assert report.recipients == [user.email]
    end
  end

  describe "POST /sites/:website/monthly-report/disable" do
    setup [:create_user, :log_in, :create_site]

    test "deletes the monthly report record", %{conn: conn, site: site} do
      insert(:monthly_report, site: site)

      post(conn, "/sites/#{site.domain}/monthly-report/disable")

      refute Repo.get_by(Plausible.Site.MonthlyReport, site_id: site.id)
    end
  end

  describe "POST /sites/:website/monthly-report/recipients" do
    setup [:create_user, :log_in, :create_site]

    test "adds a recipient to the monthly report", %{conn: conn, site: site} do
      insert(:monthly_report, site: site)

      post(conn, "/sites/#{site.domain}/monthly-report/recipients", recipient: "user@email.com")

      report = Repo.get_by(Plausible.Site.MonthlyReport, site_id: site.id)
      assert report.recipients == ["user@email.com"]
    end
  end

  describe "DELETE /sites/:website/monthly-report/recipients/:recipient" do
    setup [:create_user, :log_in, :create_site]

    test "removes a recipient from the monthly report", %{conn: conn, site: site} do
      insert(:monthly_report, site: site, recipients: ["recipient@email.com"])

      delete(conn, "/sites/#{site.domain}/monthly-report/recipients/recipient@email.com")

      report = Repo.get_by(Plausible.Site.MonthlyReport, site_id: site.id)
      assert report.recipients == []
    end
  end

  describe "POST /sites/:website/spike-notification/enable" do
    setup [:create_user, :log_in, :create_site]

    test "creates a spike notification record with the user email", %{
      conn: conn,
      site: site,
      user: user
    } do
      post(conn, "/sites/#{site.domain}/spike-notification/enable")

      notification = Repo.get_by(Plausible.Site.SpikeNotification, site_id: site.id)
      assert notification.recipients == [user.email]
    end

    test "does not allow duplicate spike notification to be created", %{
      conn: conn,
      site: site
    } do
      post(conn, "/sites/#{site.domain}/spike-notification/enable")
      post(conn, "/sites/#{site.domain}/spike-notification/enable")

      assert Repo.aggregate(
               from(s in Plausible.Site.SpikeNotification, where: s.site_id == ^site.id),
               :count
             ) == 1
    end
  end

  describe "POST /sites/:website/spike-notification/disable" do
    setup [:create_user, :log_in, :create_site]

    test "deletes the spike notification record", %{conn: conn, site: site} do
      insert(:spike_notification, site: site)

      post(conn, "/sites/#{site.domain}/spike-notification/disable")

      refute Repo.get_by(Plausible.Site.SpikeNotification, site_id: site.id)
    end
  end

  describe "PUT /sites/:website/spike-notification" do
    setup [:create_user, :log_in, :create_site]

    test "updates spike notification threshold", %{conn: conn, site: site} do
      insert(:spike_notification, site: site, threshold: 10)

      put(conn, "/sites/#{site.domain}/spike-notification", %{
        "spike_notification" => %{"threshold" => "15"}
      })

      notification = Repo.get_by(Plausible.Site.SpikeNotification, site_id: site.id)
      assert notification.threshold == 15
    end
  end

  describe "POST /sites/:website/spike-notification/recipients" do
    setup [:create_user, :log_in, :create_site]

    test "adds a recipient to the spike notification", %{conn: conn, site: site} do
      insert(:spike_notification, site: site)

      post(conn, "/sites/#{site.domain}/spike-notification/recipients",
        recipient: "user@email.com"
      )

      report = Repo.get_by(Plausible.Site.SpikeNotification, site_id: site.id)
      assert report.recipients == ["user@email.com"]
    end
  end

  describe "DELETE /sites/:website/spike-notification/recipients/:recipient" do
    setup [:create_user, :log_in, :create_site]

    test "removes a recipient from the spike notification", %{conn: conn, site: site} do
      insert(:spike_notification, site: site, recipients: ["recipient@email.com"])

      delete(conn, "/sites/#{site.domain}/spike-notification/recipients/recipient@email.com")

      report = Repo.get_by(Plausible.Site.SpikeNotification, site_id: site.id)
      assert report.recipients == []
    end
  end

  describe "GET /sites/:website/shared-links/new" do
    setup [:create_user, :log_in, :create_site]

    test "shows form for new shared link", %{conn: conn, site: site} do
      conn = get(conn, "/sites/#{site.domain}/shared-links/new")

      assert html_response(conn, 200) =~ "New shared link"
    end
  end

  describe "POST /sites/:website/shared-links" do
    setup [:create_user, :log_in, :create_site]

    test "creates shared link without password", %{conn: conn, site: site} do
      post(conn, "/sites/#{site.domain}/shared-links", %{
        "shared_link" => %{"name" => "Link name"}
      })

      link = Repo.one(Plausible.Site.SharedLink)

      refute is_nil(link.slug)
      assert is_nil(link.password_hash)
      assert link.name == "Link name"
    end

    test "creates shared link with password", %{conn: conn, site: site} do
      post(conn, "/sites/#{site.domain}/shared-links", %{
        "shared_link" => %{"password" => "password", "name" => "New name"}
      })

      link = Repo.one(Plausible.Site.SharedLink)

      refute is_nil(link.slug)
      refute is_nil(link.password_hash)
      assert link.name == "New name"
    end
  end

  describe "GET /sites/:website/shared-links/edit" do
    setup [:create_user, :log_in, :create_site]

    test "shows form to edit shared link", %{conn: conn, site: site} do
      link = insert(:shared_link, site: site)
      conn = get(conn, "/sites/#{site.domain}/shared-links/#{link.slug}/edit")

      assert html_response(conn, 200) =~ "Edit shared link"
    end
  end

  describe "PUT /sites/:website/shared-links/:slug" do
    setup [:create_user, :log_in, :create_site]

    test "can update link name", %{conn: conn, site: site} do
      link = insert(:shared_link, site: site)

      put(conn, "/sites/#{site.domain}/shared-links/#{link.slug}", %{
        "shared_link" => %{"name" => "Updated link name"}
      })

      link = Repo.one(Plausible.Site.SharedLink)

      assert link.name == "Updated link name"
    end
  end

  describe "DELETE /sites/:website/shared-links/:slug" do
    setup [:create_user, :log_in, :create_site]

    test "shows form for new shared link", %{conn: conn, site: site} do
      link = insert(:shared_link, site: site)

      conn = delete(conn, "/sites/#{site.domain}/shared-links/#{link.slug}")

      refute Repo.one(Plausible.Site.SharedLink)
      assert redirected_to(conn, 302) =~ "/#{site.domain}/settings"
    end
  end

  describe "DELETE sites/:website/custom-domains/:id" do
    setup [:create_user, :log_in, :create_site]

    test "lists goals for the site", %{conn: conn, site: site} do
      domain = insert(:custom_domain, site: site)

      delete(conn, "/sites/#{site.domain}/custom-domains/#{domain.id}")

      assert Repo.aggregate(Plausible.Site.CustomDomain, :count, :id) == 0
    end
  end

  describe "POST /:website/settings/google-import" do
    setup [:create_user, :log_in, :create_new_site]

    test "adds in-progress imported tag to site", %{conn: conn, site: site} do
      post(conn, "/#{site.domain}/settings/google-import", %{
        "view_id" => "123",
        "start_date" => "2018-03-01",
        "end_date" => "2022-03-01",
        "access_token" => "token"
      })

      imported_data = Repo.reload(site).imported_data

      assert imported_data
      assert imported_data.source == "Google Analytics"
      assert imported_data.end_date == ~D[2022-03-01]
      assert imported_data.status == "importing"
    end

    test "schedules an import job in Oban", %{conn: conn, site: site} do
      post(conn, "/#{site.domain}/settings/google-import", %{
        "view_id" => "123",
        "start_date" => "2018-03-01",
        "end_date" => "2022-03-01",
        "access_token" => "token"
      })

      assert_enqueued(
        worker: Plausible.Workers.ImportGoogleAnalytics,
        args: %{
          "site_id" => site.id,
          "view_id" => "123",
          "start_date" => "2018-03-01",
          "end_date" => "2022-03-01",
          "access_token" => "token"
        }
      )
    end
  end

  describe "DELETE /:website/settings/:forget_imported" do
    setup [:create_user, :log_in, :create_new_site]

    test "removes imported_data field from site", %{conn: conn, site: site} do
      delete(conn, "/#{site.domain}/settings/forget-imported")

      assert Repo.reload(site).imported_data == nil
    end

    test "removes actual imported data from Clickhouse", %{conn: conn, site: site} do
      Plausible.Site.start_import(site, ~D[2022-01-01], Timex.today(), "Google Analytics")
      |> Repo.update!()

      populate_stats(site, [
        build(:imported_visitors, pageviews: 10)
      ])

      delete(conn, "/#{site.domain}/settings/forget-imported")

      assert Plausible.Stats.Clickhouse.imported_pageview_count(site) == 0
    end

    test "cancels Oban job if it exists", %{conn: conn, site: site} do
      {:ok, job} =
        Plausible.Workers.ImportGoogleAnalytics.new(%{
          "site_id" => site.id,
          "view_id" => "123",
          "start_date" => "2022-01-01",
          "end_date" => "2023-01-01",
          "access_token" => "token"
        })
        |> Oban.insert()

      Plausible.Site.start_import(site, ~D[2022-01-01], Timex.today(), "Google Analytics")
      |> Repo.update!()

      populate_stats(site, [
        build(:imported_visitors, pageviews: 10)
      ])

      delete(conn, "/#{site.domain}/settings/forget-imported")

      assert Repo.reload(job).state == "cancelled"
    end
  end
end
