defmodule PlausibleWeb.SiteControllerTest do
  use PlausibleWeb.ConnCase, async: false
  use Plausible.Repo
  use Bamboo.Test
  use Oban.Testing, repo: Plausible.Repo

  import ExUnit.CaptureLog
  import Mox
  setup :verify_on_exit!

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
      site = insert(:site, members: [user])

      populate_stats(site, [build(:pageview), build(:pageview), build(:pageview)])
      conn = get(conn, "/sites")

      assert html_response(conn, 200) =~ site.domain
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
      assert site = Repo.get_by(Plausible.Site, domain: "example.com")
      assert site.domain == "example.com"
      assert site.timezone == "Europe/London"
      assert site.ingest_rate_limit_scale_seconds == 60
      assert site.ingest_rate_limit_threshold == 1_000_000
    end

    test "fails to create the site if only http:// provided", %{conn: conn} do
      conn =
        post(conn, "/sites", %{
          "site" => %{
            "domain" => "http://",
            "timezone" => "Europe/London"
          }
        })

      assert html_response(conn, 200) =~ "can&#39;t be blank"
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
      insert_list(50, :site, members: [user])

      conn =
        post(conn, "/sites", %{
          "site" => %{
            "domain" => "over-limit.example.com",
            "timezone" => "Europe/London"
          }
        })

      assert html = html_response(conn, 200)
      assert html =~ "Upgrade required"
      assert html =~ "Your account is limited to 50 sites"
      assert html =~ "Please contact support"
      refute Repo.get_by(Plausible.Site, domain: "over-limit.example.com")
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
      assert Repo.get_by(Plausible.Site, domain: "example.com")
    end

    test "allows enterprise accounts to create unlimited sites", %{
      conn: conn,
      user: user
    } do
      ep = insert(:enterprise_plan, user: user)
      insert(:subscription, user: user, paddle_plan_id: ep.paddle_plan_id)

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
      assert Repo.get_by(Plausible.Site, domain: "example.com")
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
      assert Repo.get_by(Plausible.Site, domain: "example.com")
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
               "This domain cannot be registered. Perhaps one of your colleagues registered it?"
    end

    test "renders form again when domain was changed from elsewhere", %{conn: conn} do
      :site
      |> insert(domain: "example.com")
      |> Plausible.Site.Domain.change("new.example.com")

      conn =
        post(conn, "/sites", %{
          "site" => %{
            "domain" => "example.com",
            "timezone" => "Europe/London"
          }
        })

      assert html_response(conn, 200) =~
               "This domain cannot be registered. Perhaps one of your colleagues registered it?"
    end
  end

  describe "GET /:website/snippet" do
    setup [:create_user, :log_in, :create_site]

    test "shows snippet", %{conn: conn, site: site} do
      conn = get(conn, "/#{site.domain}/snippet")

      assert html_response(conn, 200) =~ "Add JavaScript snippet"
    end
  end

  describe "GET /:website/settings/general" do
    setup [:create_user, :log_in, :create_site]

    setup_patch_env(:google, client_id: "some", api_url: "https://www.googleapis.com")

    test "shows settings form", %{conn: conn, site: site} do
      conn = get(conn, "/#{site.domain}/settings/general")
      resp = html_response(conn, 200)

      assert resp =~ "Site timezone"
      assert resp =~ "Data Import from Google Analytics"
      assert resp =~ "https://accounts.google.com/o/oauth2/v2/auth?"
      assert resp =~ "analytics.readonly"
      refute resp =~ "webmasters.readonly"
    end
  end

  describe "GET /:website/settings/goals" do
    setup [:create_user, :log_in, :create_site]

    test "lists goals for the site", %{conn: conn, site: site} do
      insert(:goal, site: site, event_name: "Custom event")
      insert(:goal, site: site, page_path: "/register")

      conn = get(conn, "/#{site.domain}/settings/goals")

      assert html_response(conn, 200) =~ "Custom event"
      assert html_response(conn, 200) =~ "Visit /register"
    end

    test "goal names are HTML safe", %{conn: conn, site: site} do
      insert(:goal, site: site, event_name: "<some_event>")

      conn = get(conn, "/#{site.domain}/settings/goals")

      resp = html_response(conn, 200)
      assert resp =~ "&lt;some_event&gt;"
      refute resp =~ "<some_event>"
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

    test "fails to make site public with insufficient permissions", %{conn: conn, user: user} do
      site = insert(:site, memberships: [build(:site_membership, user: user, role: :viewer)])
      conn = post(conn, "/sites/#{site.domain}/make-public")
      assert conn.status == 404
      refute Repo.get(Plausible.Site, site.id).public
    end

    test "fails to make foreign site public", %{conn: my_conn, user: me} do
      _my_site = insert(:site, memberships: [build(:site_membership, user: me, role: :owner)])

      other_user = insert(:user)
      other_site = insert(:site)
      insert(:site_membership, site: other_site, user: other_user, role: "owner")

      my_conn = post(my_conn, "/sites/#{other_site.domain}/make-public")
      assert my_conn.status == 404
      refute Repo.get(Plausible.Site, other_site.id).public
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

      refute Repo.exists?(from(s in Plausible.Site, where: s.id == ^site.id))
    end

    test "fails to delete a site with insufficient permissions", %{conn: conn, user: user} do
      site = insert(:site, memberships: [build(:site_membership, user: user, role: :viewer)])
      insert(:google_auth, user: user, site: site)
      insert(:custom_domain, site: site)
      insert(:spike_notification, site: site)

      conn = delete(conn, "/#{site.domain}")

      assert conn.status == 404
      assert Repo.exists?(from(s in Plausible.Site, where: s.id == ^site.id))
    end

    test "fails to delete a foreign site", %{conn: my_conn, user: me} do
      _my_site = insert(:site, memberships: [build(:site_membership, user: me, role: :owner)])

      other_user = insert(:user)
      other_site = insert(:site)
      insert(:site_membership, site: other_site, user: other_user, role: "owner")
      insert(:google_auth, user: other_user, site: other_site)
      insert(:custom_domain, site: other_site)
      insert(:spike_notification, site: other_site)

      my_conn = delete(my_conn, "/#{other_site.domain}")
      assert my_conn.status == 404
      assert Repo.exists?(from(s in Plausible.Site, where: s.id == ^other_site.id))
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

    test "fails to delete associated google auth from the outside", %{
      conn: conn,
      user: user
    } do
      other_site = insert(:site)
      insert(:google_auth, user: user, site: other_site)
      conn = delete(conn, "/#{other_site.domain}/settings/google-search")

      assert conn.status == 404
      assert Repo.exists?(Plausible.Site.GoogleAuth)
    end
  end

  describe "GET /:website/settings/search-console for self-hosting" do
    setup [:create_user, :log_in, :create_site]

    test "display search console settings", %{conn: conn, site: site} do
      conn = get(conn, "/#{site.domain}/settings/search-console")
      resp = html_response(conn, 200)
      assert resp =~ "An extra step is needed"
      assert resp =~ "Google Search Console integration"
      assert resp =~ "self-hosting-configuration"
    end
  end

  describe "GET /:website/settings/search-console" do
    setup [:create_user, :log_in, :create_site]

    setup_patch_env(:google, client_id: "some", api_url: "https://www.googleapis.com")

    setup %{site: site, user: user} = context do
      insert(:google_auth, user: user, site: site, property: "sc-domain:#{site.domain}")
      context
    end

    test "displays Continue with Google link", %{conn: conn, user: user} do
      site = insert(:site, domain: "notconnectedyet.example.com", members: [user])

      conn = get(conn, "/#{site.domain}/settings/search-console")
      resp = html_response(conn, 200)
      assert resp =~ "Continue with Google"
      assert resp =~ "https://accounts.google.com/o/oauth2/v2/auth?"
      assert resp =~ "webmasters.readonly"
      refute resp =~ "analytics.readonly"
    end

    test "displays appropriate error in case of google account `google_auth_error`", %{
      conn: conn,
      site: site
    } do
      expect(
        Plausible.HTTPClient.Mock,
        :get,
        fn
          "https://www.googleapis.com/webmasters/v3/sites",
          [{"Content-Type", "application/json"}, {"Authorization", "Bearer 123"}] ->
            {:error, %{reason: %Finch.Response{status: Enum.random([401, 403])}}}
        end
      )

      conn = get(conn, "/#{site.domain}/settings/search-console")
      resp = html_response(conn, 200)
      assert resp =~ "Your Search Console account hasn't been connected successfully"
      assert resp =~ "Please unlink your Google account and try linking it again"
    end

    test "displays docs link error in case of `invalid_grant`", %{
      conn: conn,
      site: site
    } do
      expect(
        Plausible.HTTPClient.Mock,
        :get,
        fn
          "https://www.googleapis.com/webmasters/v3/sites",
          [{"Content-Type", "application/json"}, {"Authorization", "Bearer 123"}] ->
            {:error, %{reason: %Finch.Response{status: 400, body: %{"error" => "invalid_grant"}}}}
        end
      )

      conn = get(conn, "/#{site.domain}/settings/search-console")
      resp = html_response(conn, 200)

      assert resp =~
               "https://plausible.io/docs/google-search-console-integration#i-get-the-invalid-grant-error"
    end

    test "displays generic error in case of random error code returned by google", %{
      conn: conn,
      site: site
    } do
      expect(
        Plausible.HTTPClient.Mock,
        :get,
        fn
          "https://www.googleapis.com/webmasters/v3/sites",
          [{"Content-Type", "application/json"}, {"Authorization", "Bearer 123"}] ->
            {:error, %{reason: %Finch.Response{status: 503, body: %{"error" => "some_error"}}}}
        end
      )

      conn = get(conn, "/#{site.domain}/settings/search-console")
      resp = html_response(conn, 200)

      assert resp =~ "Something went wrong, but looks temporary"
      assert resp =~ "try re-linking your Google account"
    end

    test "displays generic error and logs a message, in case of random HTTP failure calling google",
         %{
           conn: conn,
           site: site
         } do
      expect(
        Plausible.HTTPClient.Mock,
        :get,
        fn
          "https://www.googleapis.com/webmasters/v3/sites",
          [{"Content-Type", "application/json"}, {"Authorization", "Bearer 123"}] ->
            {:error, :nxdomain}
        end
      )

      log =
        capture_log(fn ->
          conn = get(conn, "/#{site.domain}/settings/search-console")
          resp = html_response(conn, 200)

          assert resp =~ "Something went wrong, but looks temporary"
          assert resp =~ "try re-linking your Google account"
        end)

      assert log =~ "Google Analytics: failed to list sites: :nxdomain"
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

    test "creates a custom event goal with a revenue value", %{conn: conn, site: site} do
      conn =
        post(conn, "/#{site.domain}/goals", %{
          goal: %{
            page_path: "",
            event_name: "Purchase",
            currency: "EUR"
          }
        })

      goal = Repo.get_by(Plausible.Goal, site_id: site.id)

      assert goal.event_name == "Purchase"
      assert goal.page_path == nil
      assert goal.currency == :EUR

      assert redirected_to(conn, 302) == "/#{site.domain}/settings/goals"
    end

    test "fails to create a custom event goal with a non-existant currency", %{
      conn: conn,
      site: site
    } do
      conn =
        post(conn, "/#{site.domain}/goals", %{
          goal: %{
            page_path: "",
            event_name: "Purchase",
            currency: "EEEE"
          }
        })

      refute Repo.get_by(Plausible.Goal, site_id: site.id)

      assert html_response(conn, 200) =~ "is invalid"
    end

    test "Cleans currency for pageview goal creation", %{conn: conn, site: site} do
      conn =
        post(conn, "/#{site.domain}/goals", %{
          goal: %{
            page_path: "/purchase",
            event_name: "",
            currency: "EUR"
          }
        })

      goal = Repo.get_by(Plausible.Goal, site_id: site.id)

      assert goal.event_name == nil
      assert goal.page_path == "/purchase"
      assert goal.currency == nil

      assert redirected_to(conn, 302) == "/#{site.domain}/settings/goals"
    end
  end

  describe "DELETE /:website/goals/:id" do
    setup [:create_user, :log_in, :create_site]

    test "deletes goal", %{conn: conn, site: site} do
      goal = insert(:goal, site: site, event_name: "Custom event")

      conn = delete(conn, "/#{site.domain}/goals/#{goal.id}")

      assert Repo.aggregate(Plausible.Goal, :count, :id) == 0
      assert redirected_to(conn, 302) == "/#{site.domain}/settings/goals"
    end

    test "fails to delete goal for a foreign site", %{conn: conn, site: site} do
      another_site = insert(:site)
      goal = insert(:goal, site: another_site, event_name: "Custom event")

      conn = delete(conn, "/#{site.domain}/goals/#{goal.id}")

      assert Repo.aggregate(Plausible.Goal, :count, :id) == 1
      assert Phoenix.Flash.get(conn.assigns.flash, :error) == "Could not find goal"
    end
  end

  describe "PUT /:website/settings/features/visibility/:setting" do
    def build_conn_with_some_url(context) do
      {:ok, Map.put(context, :conn, build_conn(:get, "/some_parent_path"))}
    end

    setup [:build_conn_with_some_url, :create_user, :log_in]

    for {title, setting} <- %{
          "Goals" => :conversions_enabled,
          "Funnels" => :funnels_enabled,
          "Properties" => :props_enabled
        } do
      test "can toggle #{title} with admin access", %{
        user: user,
        conn: conn0
      } do
        site = insert(:site)
        insert(:site_membership, user: user, site: site, role: :admin)

        conn =
          put(
            conn0,
            PlausibleWeb.Components.Site.Feature.target(site, unquote(setting), conn0, false)
          )

        assert Phoenix.Flash.get(conn.assigns.flash, :success) ==
                 "#{unquote(title)} are now hidden from your dashboard"

        assert redirected_to(conn, 302) =~ "/some_parent_path"

        assert %{unquote(setting) => false} = Plausible.Sites.get_by_domain(site.domain)

        conn =
          put(
            conn0,
            PlausibleWeb.Components.Site.Feature.target(site, unquote(setting), conn0, true)
          )

        assert Phoenix.Flash.get(conn.assigns.flash, :success) ==
                 "#{unquote(title)} are now visible again on your dashboard"

        assert redirected_to(conn, 302) =~ "/some_parent_path"

        assert %{unquote(setting) => true} = Plausible.Sites.get_by_domain(site.domain)
      end
    end

    for {title, setting} <- %{
          "Goals" => :conversions_enabled,
          "Funnels" => :funnels_enabled,
          "Properties" => :props_enabled
        } do
      test "cannot toggle #{title} with viewer access", %{
        user: user,
        conn: conn0
      } do
        site = insert(:site)
        insert(:site_membership, user: user, site: site, role: :viewer)

        conn =
          put(
            conn0,
            PlausibleWeb.Components.Site.Feature.target(site, unquote(setting), conn0, false)
          )

        assert conn.status == 404
        assert conn.halted
      end
    end

    test "setting feature visibility is idempotent", %{user: user, conn: conn0} do
      site = insert(:site)
      insert(:site_membership, user: user, site: site, role: :admin)

      setting = :funnels_enabled

      conn =
        put(
          conn0,
          PlausibleWeb.Components.Site.Feature.target(site, setting, conn0, false)
        )

      assert %{^setting => false} = Plausible.Sites.get_by_domain(site.domain)
      assert redirected_to(conn, 302) =~ "/some_parent_path"

      conn =
        put(
          conn0,
          PlausibleWeb.Components.Site.Feature.target(site, setting, conn0, false)
        )

      assert %{^setting => false} = Plausible.Sites.get_by_domain(site.domain)
      assert redirected_to(conn, 302) =~ "/some_parent_path"
    end
  end

  describe "POST /sites/:website/weekly-report/enable" do
    setup [:create_user, :log_in, :create_site]

    test "creates a weekly report record with the user email", %{
      conn: conn,
      site: site,
      user: user
    } do
      conn = post(conn, "/sites/#{site.domain}/weekly-report/enable")
      assert Phoenix.Flash.get(conn.assigns.flash, :success) =~ "You will receive an email report"

      report = Repo.get_by(Plausible.Site.WeeklyReport, site_id: site.id)
      assert report.recipients == [user.email]
    end

    test "creates a weekly report record twice (e.g. from a second tab)", %{
      conn: conn,
      site: site,
      user: user
    } do
      post(conn, "/sites/#{site.domain}/weekly-report/enable")
      conn = post(conn, "/sites/#{site.domain}/weekly-report/enable")
      assert Phoenix.Flash.get(conn.assigns.flash, :success) =~ "You will receive an email report"

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

    test "fails to delete the weekly report record for a foreign site", %{conn: conn} do
      site = insert(:site)
      insert(:weekly_report, site: site)

      post(conn, "/sites/#{site.domain}/weekly-report/disable")

      assert Repo.get_by(Plausible.Site.WeeklyReport, site_id: site.id)
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

    test "fails to remove a recipient from the weekly report in a foreign website", %{conn: conn} do
      site = insert(:site)
      insert(:weekly_report, site: site, recipients: ["recipient@email.com"])

      conn = delete(conn, "/sites/#{site.domain}/weekly-report/recipients/recipient@email.com")
      assert conn.status == 404

      conn = delete(conn, "/sites/#{site.domain}/weekly-report/recipients/recipient%40email.com")
      assert conn.status == 404

      report = Repo.get_by(Plausible.Site.WeeklyReport, site_id: site.id)
      assert [_] = report.recipients
    end
  end

  describe "POST /sites/:website/monthly-report/enable" do
    setup [:create_user, :log_in, :create_site]

    test "creates a monthly report record with the user email", %{
      conn: conn,
      site: site,
      user: user
    } do
      conn = post(conn, "/sites/#{site.domain}/monthly-report/enable")

      report = Repo.get_by(Plausible.Site.MonthlyReport, site_id: site.id)
      assert report.recipients == [user.email]
      assert Phoenix.Flash.get(conn.assigns.flash, :success) =~ "You will receive an email report"
    end

    test "enable monthly report twice (e.g. from a second tab)", %{
      conn: conn,
      site: site,
      user: user
    } do
      post(conn, "/sites/#{site.domain}/monthly-report/enable")
      conn = post(conn, "/sites/#{site.domain}/monthly-report/enable")

      assert Phoenix.Flash.get(conn.assigns.flash, :success) =~ "You will receive an email report"
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

    test "fails to remove a recipient from the monthly report in a foreign website", %{
      conn: conn
    } do
      site = insert(:site)
      insert(:monthly_report, site: site, recipients: ["recipient@email.com"])

      conn = delete(conn, "/sites/#{site.domain}/monthly-report/recipients/recipient@email.com")
      assert conn.status == 404

      conn = delete(conn, "/sites/#{site.domain}/monthly-report/recipients/recipient%40email.com")
      assert conn.status == 404

      report = Repo.get_by(Plausible.Site.MonthlyReport, site_id: site.id)
      assert [_] = report.recipients
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

    test "fails to remove a recipient from the spike notification in a foreign website", %{
      conn: conn
    } do
      site = insert(:site)
      insert(:spike_notification, site: site, recipients: ["recipient@email.com"])

      conn =
        delete(conn, "/sites/#{site.domain}/spike-notification/recipients/recipient@email.com")

      assert conn.status == 404

      conn =
        delete(conn, "/sites/#{site.domain}/spike-notification/recipients/recipient%40email.com")

      assert conn.status == 404

      report = Repo.get_by(Plausible.Site.SpikeNotification, site_id: site.id)
      assert [_] = report.recipients
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

    test "deletes shared link", %{conn: conn, site: site} do
      link = insert(:shared_link, site: site)

      conn = delete(conn, "/sites/#{site.domain}/shared-links/#{link.slug}")

      refute Repo.one(Plausible.Site.SharedLink)
      assert redirected_to(conn, 302) =~ "/#{site.domain}/settings"
      assert Phoenix.Flash.get(conn.assigns.flash, :success) == "Shared Link deleted"
    end

    test "fails to delete shared link from the outside", %{conn: conn, site: site} do
      other_site = insert(:site)
      link = insert(:shared_link, site: other_site)

      conn = delete(conn, "/sites/#{site.domain}/shared-links/#{link.slug}")

      assert Repo.one(Plausible.Site.SharedLink)
      assert redirected_to(conn, 302) =~ "/#{site.domain}/settings"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) == "Could not find Shared Link"
    end
  end

  describe "DELETE sites/:website/custom-domains/:id" do
    setup [:create_user, :log_in, :create_site]

    test "deletes custom domain", %{conn: conn, site: site} do
      domain = insert(:custom_domain, site: site)

      conn = delete(conn, "/sites/#{site.domain}/custom-domains/#{domain.id}")

      assert Phoenix.Flash.get(conn.assigns.flash, :success) ==
               "Custom domain deleted successfully"

      assert Repo.aggregate(Plausible.Site.CustomDomain, :count, :id) == 0
    end

    test "fails to delete custom domain not owning it", %{conn: conn, site: site} do
      _og_domain = insert(:custom_domain, site: site)

      foreign_site = insert(:site)
      foreign_domain = insert(:custom_domain, site: foreign_site)

      assert Repo.aggregate(Plausible.Site.CustomDomain, :count, :id) == 2

      conn = delete(conn, "/sites/#{site.domain}/custom-domains/#{foreign_domain.id}")
      assert Phoenix.Flash.get(conn.assigns.flash, :error) == "Failed to delete custom domain"

      assert Repo.aggregate(Plausible.Site.CustomDomain, :count, :id) == 2
    end
  end

  describe "GET /:website/import/google-analytics/view-id" do
    setup [:create_user, :log_in, :create_new_site]

    test "lists Google Analytics views", %{conn: conn, site: site} do
      expect(
        Plausible.HTTPClient.Mock,
        :get,
        fn _url, _body ->
          body = "fixture/ga_list_views.json" |> File.read!() |> Jason.decode!()
          {:ok, %Finch.Response{body: body, status: 200}}
        end
      )

      response =
        conn
        |> get("/#{site.domain}/import/google-analytics/view-id", %{
          "access_token" => "token",
          "refresh_token" => "foo",
          "expires_at" => "2022-09-22T20:01:37.112777"
        })
        |> html_response(200)

      assert response =~ "57238190 - one.test"
      assert response =~ "54460083 - two.test"
    end
  end

  describe "POST /:website/settings/google-import" do
    setup [:create_user, :log_in, :create_new_site]

    test "adds in-progress imported tag to site", %{conn: conn, site: site} do
      post(conn, "/#{site.domain}/settings/google-import", %{
        "view_id" => "123",
        "start_date" => "2018-03-01",
        "end_date" => "2022-03-01",
        "access_token" => "token",
        "refresh_token" => "foo",
        "expires_at" => "2022-09-22T20:01:37.112777"
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
        "access_token" => "token",
        "refresh_token" => "foo",
        "expires_at" => "2022-09-22T20:01:37.112777"
      })

      assert_enqueued(
        worker: Plausible.Workers.ImportGoogleAnalytics,
        args: %{
          "site_id" => site.id,
          "view_id" => "123",
          "start_date" => "2018-03-01",
          "end_date" => "2022-03-01",
          "access_token" => "token",
          "refresh_token" => "foo",
          "token_expires_at" => "2022-09-22T20:01:37.112777"
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

      assert eventually(fn ->
               count = Plausible.Stats.Clickhouse.imported_pageview_count(site)
               {count == 0, count}
             end)
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

  describe "domain change" do
    setup [:create_user, :log_in, :create_site]

    test "shows domain change in the settings form", %{conn: conn, site: site} do
      conn = get(conn, Routes.site_path(conn, :settings_general, site.domain))
      resp = html_response(conn, 200)

      assert resp =~ "Site domain"
      assert resp =~ "Change domain"
      assert resp =~ Routes.site_path(conn, :change_domain, site.domain)
    end

    test "domain change form renders", %{conn: conn, site: site} do
      conn = get(conn, Routes.site_path(conn, :change_domain, site.domain))
      resp = html_response(conn, 200)
      assert resp =~ Routes.site_path(conn, :change_domain_submit, site.domain)

      assert resp =~
               "Once you change your domain, you must update the JavaScript snippet on your site within 72 hours"
    end

    test "domain change form submission when no change is made", %{conn: conn, site: site} do
      conn =
        put(conn, Routes.site_path(conn, :change_domain_submit, site.domain), %{
          "site" => %{"domain" => site.domain}
        })

      resp = html_response(conn, 200)
      assert resp =~ "New domain must be different than the current one"
    end

    test "domain change form submission to an existing domain", %{conn: conn, site: site} do
      another_site = insert(:site)

      conn =
        put(conn, Routes.site_path(conn, :change_domain_submit, site.domain), %{
          "site" => %{"domain" => another_site.domain}
        })

      resp = html_response(conn, 200)
      assert resp =~ "This domain cannot be registered"

      site = Repo.reload!(site)
      assert site.domain != another_site.domain
      assert is_nil(site.domain_changed_from)
    end

    test "domain change form submission to a domain in transition period", %{
      conn: conn,
      site: site
    } do
      another_site = insert(:site, domain_changed_from: "foo.example.com")

      conn =
        put(conn, Routes.site_path(conn, :change_domain_submit, site.domain), %{
          "site" => %{"domain" => "foo.example.com"}
        })

      resp = html_response(conn, 200)
      assert resp =~ "This domain cannot be registered"

      site = Repo.reload!(site)
      assert site.domain != another_site.domain
      assert is_nil(site.domain_changed_from)
    end

    test "domain change succcessful form submission redirects to snippet change info", %{
      conn: conn,
      site: site
    } do
      original_domain = site.domain

      conn =
        put(conn, Routes.site_path(conn, :change_domain_submit, site.domain), %{
          "site" => %{"domain" => "foo.example.com"}
        })

      assert redirected_to(conn) ==
               Routes.site_path(conn, :add_snippet_after_domain_change, "foo.example.com")

      site = Repo.reload!(site)
      assert site.domain == "foo.example.com"
      assert site.domain_changed_from == original_domain
    end

    test "snippet info after domain change", %{
      conn: conn,
      site: site
    } do
      put(conn, Routes.site_path(conn, :change_domain_submit, site.domain), %{
        "site" => %{"domain" => "foo.example.com"}
      })

      resp =
        conn
        |> get(Routes.site_path(conn, :add_snippet_after_domain_change, "foo.example.com"))
        |> html_response(200)
        |> Floki.parse_document!()
        |> Floki.text()

      assert resp =~
               "Your domain has been changed. You must update the JavaScript snippet on your site within 72 hours"
    end
  end
end
