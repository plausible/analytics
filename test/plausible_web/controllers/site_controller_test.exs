defmodule PlausibleWeb.SiteControllerTest do
  use PlausibleWeb.ConnCase, async: false
  use Plausible.Repo
  use Bamboo.Test
  use Oban.Testing, repo: Plausible.Repo
  use Plausible.Teams.Test

  import ExUnit.CaptureLog
  import Mox
  import Plausible.Test.Support.HTML

  alias Plausible.Imported.SiteImport
  alias Plausible.Teams

  require Plausible.Imported.SiteImport

  @v4_business_plan_id "857105"

  setup :verify_on_exit!

  describe "GET /sites/new" do
    setup [:create_user, :log_in]

    test "shows the site form", %{conn: conn} do
      conn = get(conn, "/sites/new")

      assert html_response(conn, 200) =~ "Add website info"
    end

    test "shows onboarding steps regardless of sites provisioned", %{conn: conn1, user: user} do
      conn = get(conn1, "/sites/new")

      assert html_response(conn, 200) =~ "Add site info"

      new_site(owner: user, domain: "test-site.com")

      conn = get(conn1, "/sites/new")

      assert html_response(conn, 200) =~ "Add site info"
    end

    test "does not display limit notice when user is on an enterprise plan", %{
      conn: conn,
      user: user
    } do
      subscribe_to_enterprise_plan(user)

      new_site(owner: user)
      new_site(owner: user)
      new_site(owner: user)

      conn = get(conn, "/sites/new")
      refute html_response(conn, 200) =~ "is limited to"
    end
  end

  describe "GET /sites" do
    setup [:create_user, :log_in]

    test "shows empty screen if no sites", %{conn: conn} do
      conn = get(conn, "/sites")
      assert html_response(conn, 200) =~ "You don't have any sites yet"
    end

    test "lists all of your sites with last 24h visitors (defaulting to 0 on first mount)", %{
      conn: conn,
      user: user
    } do
      site = new_site(owner: user)

      # will be skipped
      populate_stats(site, [build(:pageview)])
      conn = get(conn, "/sites")

      assert resp = html_response(conn, 200)

      site_card = text_of_element(resp, "li[data-domain=\"#{site.domain}\"]")

      refute site_card =~ "0 visitors"
      assert site_card =~ site.domain
    end

    test "shows invitations for user by email address", %{conn: conn, user: user} do
      inviter = new_user()
      site = new_site(owner: inviter)
      invite_guest(site, user, inviter: inviter, role: :editor)
      conn = get(conn, "/sites")

      assert html_response(conn, 200) =~ site.domain
    end

    test "invitations are case insensitive", %{conn: conn, user: user} do
      inviter = new_user()
      site = new_site(owner: inviter)
      invite_guest(site, String.upcase(user.email), inviter: inviter, role: :editor)

      conn = get(conn, "/sites")

      assert html_response(conn, 200) =~ site.domain
    end

    test "paginates sites", %{conn: initial_conn, user: user} do
      for i <- 1..25 do
        new_site(
          owner: user,
          domain: "paginated-site#{String.pad_leading("#{i}", 2, "0")}.example.com"
        )
      end

      conn = get(initial_conn, "/sites")
      resp = html_response(conn, 200)

      for i <- 1..24 do
        assert element_exists?(
                 resp,
                 "li[data-domain=\"paginated-site#{String.pad_leading("#{i}", 2, "0")}.example.com\"]"
               )
      end

      refute resp =~ "paginated-site25.com"

      next_page_link = text_of_attr(resp, ".pagination-link.active", "href")
      next_page = initial_conn |> get(next_page_link) |> html_response(200)

      assert element_exists?(
               next_page,
               "li[data-domain=\"paginated-site25.example.com\"]"
             )

      prev_page_link = text_of_attr(next_page, ".pagination-link.active", "href")
      prev_page = initial_conn |> get(prev_page_link) |> html_response(200)

      assert element_exists?(
               prev_page,
               "li[data-domain=\"paginated-site04.example.com\"]"
             )

      refute element_exists?(
               prev_page,
               "li[data-domain=\"paginated-site25.example.com\"]"
             )
    end

    test "shows upgrade nag message to expired trial user without subscription", %{
      conn: initial_conn,
      user: user
    } do
      new_site(owner: user)

      conn = get(initial_conn, "/sites")
      resp = html_response(conn, 200)

      nag_message =
        "To access the sites you own, you need to subscribe to a monthly or yearly payment plan."

      refute resp =~ nag_message

      user
      |> team_of()
      |> Plausible.Teams.Team.end_trial()
      |> Repo.update!()

      conn = get(initial_conn, "/sites")
      resp = html_response(conn, 200)

      assert resp =~ nag_message
    end

    test "filters by domain", %{conn: conn, user: user} do
      _site1 = new_site(domain: "first.example.com", owner: user)
      _site2 = new_site(domain: "second.example.com", owner: user)
      _rogue_site = new_site()

      inviter = new_user()

      new_site(owner: inviter, domain: "first-another.example.com")
      |> invite_guest(user, inviter: inviter, role: :viewer)

      conn = get(conn, "/sites", filter_text: "first")
      resp = html_response(conn, 200)

      assert resp =~ "first.example.com"
      assert resp =~ "first-another.example.com"
      refute resp =~ "second.example.com"
    end

    test "does not show empty state when filter returns empty but there are sites", %{
      conn: conn,
      user: user
    } do
      _site1 = new_site(domain: "example.com", owner: user)

      conn = get(conn, "/sites", filter_text: "none")
      resp = html_response(conn, 200)

      refute resp =~ "second.example.com"
      assert html_response(conn, 200) =~ "No sites found. Please search for something else."
      refute html_response(conn, 200) =~ "You don't have any sites yet."
    end

    test "shows settings on sites when user is an admin", %{
      conn: conn,
      user: user
    } do
      site = new_site(domain: "example.com", owner: user)
      conn = get(conn, "/sites")
      resp = html_response(conn, 200)

      assert resp =~ "/#{site.domain}/settings"
    end

    test "does not show settings on sites when user is not an admin or owner", %{
      conn: conn,
      user: user
    } do
      site = new_site(domain: "example.com")
      add_guest(site, user: user, role: :viewer)

      conn = get(conn, "/sites")
      resp = html_response(conn, 200)

      refute resp =~ "/#{site.domain}/settings"
    end
  end

  describe "POST /sites" do
    setup [:create_user, :log_in]

    test "creates the site with valid params", %{conn: conn} do
      conn =
        post(conn, "/sites", %{
          "site" => %{
            "domain" => "éxample.com",
            "timezone" => "Europe/London"
          }
        })

      assert redirected_to(conn) ==
               "/#{URI.encode_www_form("éxample.com")}/installation?site_created=true&flow="

      assert site = Repo.get_by(Plausible.Site, domain: "éxample.com")
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
      refute team_of(user)

      post(conn, "/sites", %{
        "site" => %{
          "domain" => "example.com",
          "timezone" => "Europe/London"
        }
      })

      assert Repo.reload!(team_of(user)).trial_expiry_date
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
      new_site(owner: user)

      post(conn, "/sites", %{
        "site" => %{
          "domain" => "example.com",
          "timezone" => "Europe/London"
        }
      })

      assert_no_emails_delivered()
    end

    @tag :ee_only
    test "does not allow site creation when the user is at their site limit", %{
      conn: conn,
      user: user
    } do
      for _ <- 1..10, do: new_site(owner: user)

      conn =
        post(conn, "/sites", %{
          "site" => %{
            "domain" => "over-limit.example.com",
            "timezone" => "Europe/London"
          }
        })

      assert html = html_response(conn, 200)
      assert html =~ "Your account is limited to 10 sites"
      refute Repo.get_by(Plausible.Site, domain: "over-limit.example.com")
    end

    test "does not limit accounts registered before 2021-05-05", %{
      conn: conn,
      user: user
    } do
      subscribe_to_plan(user, @v4_business_plan_id)

      for _ <- 1..51, do: new_site(owner: user)

      Ecto.Changeset.change(team_of(user), %{inserted_at: ~N[2021-05-04 00:00:00]})
      |> Repo.update()

      conn =
        post(conn, "/sites", %{
          "site" => %{
            "domain" => "example.com",
            "timezone" => "Europe/London"
          }
        })

      assert redirected_to(conn) == "/example.com/installation?site_created=true&flow="
      assert Repo.get_by(Plausible.Site, domain: "example.com")
    end

    test "does not limit enterprise accounts", %{
      conn: conn,
      user: user
    } do
      subscribe_to_enterprise_plan(user, site_limit: 1)
      team = team_of(user)
      new_site(owner: user)
      new_site(owner: user)

      conn =
        post(conn, "/sites", %{
          "site" => %{
            "domain" => "example.com",
            "timezone" => "Europe/London"
          }
        })

      assert redirected_to(conn) == "/example.com/installation?site_created=true&flow="
      assert Plausible.Teams.Billing.site_usage(team) == 3
    end

    for url <- ["https://Example.com/", "HTTPS://EXAMPLE.COM/", "/Example.com/", "//Example.com/"] do
      test "cleans up an url like #{url}", %{conn: conn} do
        conn =
          post(conn, "/sites", %{
            "site" => %{
              "domain" => unquote(url),
              "timezone" => "Europe/London"
            }
          })

        assert redirected_to(conn) == "/example.com/installation?site_created=true&flow="
        assert Repo.get_by(Plausible.Site, domain: "example.com")
      end
    end

    test "renders form again when domain is missing", %{conn: conn} do
      conn =
        post(conn, "/sites", %{
          "site" => %{
            "domain" => "",
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

      if Plausible.ee?() do
        assert html_response(conn, 200) =~ "support@plausible.io"
      else
        refute html_response(conn, 200) =~ "support@plausible.io"
      end
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

      if Plausible.ee?() do
        assert html_response(conn, 200) =~ "support@plausible.io"
      else
        refute html_response(conn, 200) =~ "support@plausible.io"
      end
    end

    test "allows creating the site if domain was changed by the owner", %{
      conn: conn,
      user: user
    } do
      new_site(domain: "example.com", owner: user)
      |> Plausible.Site.Domain.change("new.example.com")

      conn =
        post(conn, "/sites", %{
          "site" => %{
            "domain" => "example.com",
            "timezone" => "Europe/London"
          }
        })

      assert redirected_to(conn) ==
               "/example.com/installation?site_created=true&flow="
    end
  end

  describe "GET /:domain/installation" do
    setup [:create_user, :log_in, :create_site]

    test "static render - spinner determining installation type", %{
      conn: conn,
      site: site
    } do
      conn = get(conn, "/#{site.domain}/installation")

      assert html_response(conn, 200) =~ "Determining installation type"
    end
  end

  describe "GET /:domain/settings/general" do
    setup [:create_user, :log_in, :create_site]

    setup_patch_env(:google, client_id: "some", api_url: "https://www.googleapis.com")

    test "shows settings form", %{conn: conn, site: site} do
      conn = get(conn, "/#{site.domain}/settings/general")
      resp = html_response(conn, 200)

      assert resp =~ "Site Timezone"
      assert resp =~ "Site Domain"
      assert resp =~ "Site Installation"
    end
  end

  describe "GET /:domain/settings/people" do
    setup [:create_user, :log_in, :create_site]

    @tag :ee_only
    test "shows members page with links to CRM for super admin", %{
      conn: conn,
      user: user
    } do
      site = new_site(owner: user)
      patch_env(:super_admin_user_ids, [user.id])

      conn = get(conn, "/#{site.domain}/settings/people")
      resp = html_response(conn, 200)

      assert resp =~ "/crm/auth/user/#{user.id}"
    end

    test "does not show CRM links to non-super admin user", %{conn: conn, user: user} do
      site = new_site(owner: user)
      conn = get(conn, "/#{site.domain}/settings/people")
      resp = html_response(conn, 200)

      refute resp =~ "/crm/auth/user/#{user.id}"
    end

    test "lists current members", %{conn: conn, user: user} do
      site = new_site(owner: user)
      editor = add_guest(site, role: :editor)
      viewer = add_guest(site, role: :viewer)
      conn = get(conn, "/#{site.domain}/settings/people")
      resp = html_response(conn, 200)

      owner_row =
        text_of_element(resp, "#membership-#{user.id}")

      editor_row = text_of_element(resp, "#membership-#{editor.id}")
      editor_row_button = text_of_element(resp, "#membership-#{editor.id} button")
      viewer_row = text_of_element(resp, "#membership-#{viewer.id}")
      viewer_row_button = text_of_element(resp, "#membership-#{viewer.id} button")

      assert owner_row =~ user.email
      assert owner_row =~ "Owner"

      assert editor_row =~ editor.email
      assert editor_row_button == "Admin"
      refute editor_row =~ "Owner"

      assert viewer_row =~ viewer.email
      assert viewer_row_button == "Viewer"
      refute viewer_row =~ "Owner"
    end

    test "lists pending invitations", %{conn: conn, user: user} do
      site = new_site(owner: user)
      i1 = invite_guest(site, "admin@example.com", role: :editor, inviter: user)
      i2 = invite_guest(site, "viewer@example.com", role: :viewer, inviter: user)
      conn = get(conn, "/#{site.domain}/settings/people")
      resp = html_response(conn, 200)

      assert text_of_element(resp, "#invitation-#{i1.invitation_id}") == "admin@example.com Admin"

      assert text_of_element(resp, "#invitation-#{i2.invitation_id}") ==
               "viewer@example.com Viewer"
    end

    test "lists pending site transfer", %{conn: conn, user: user} do
      site = new_site(owner: user)
      new_owner = new_user()

      st = invite_transfer(site, new_owner, inviter: user)

      conn = get(conn, "/#{site.domain}/settings/people")
      resp = html_response(conn, 200)

      assert text_of_element(resp, "#invitation-#{st.transfer_id}") ==
               "#{new_owner.email} Owner"
    end

    test "renders team management notices", %{conn: conn, user: user} do
      site = new_site(owner: user)
      resp = conn |> get("/#{site.domain}/settings/people") |> html_response(200)

      refute resp =~ "You can also invite people to your team"
      refute resp =~ "Team members automatically have access to this site."

      user |> team_of() |> Teams.Team.setup_changeset() |> Repo.update!()

      resp = conn |> get("/#{site.domain}/settings/people") |> html_response(200)
      assert resp =~ "You can also invite people to your team"
      assert resp =~ "Team members automatically have access to this site."
    end

    test "does not render team management notices to editors", %{conn: conn, user: user} do
      # this can go away once we support multiple teams
      user |> team_of() |> Repo.delete!()
      owner = new_user()
      site = new_site(owner: owner)
      add_member(team_of(owner), user: user, role: :editor)

      owner |> team_of() |> Teams.Team.setup_changeset() |> Repo.update!()

      resp = conn |> get("/#{site.domain}/settings/people") |> html_response(200)

      refute resp =~ "You can also invite people to your team"
      refute resp =~ "Team members automatically have access to this site."
    end
  end

  describe "GET /:domain/settings/goals" do
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

  describe "PUT /:domain/settings" do
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
      assert redirected_to(conn, 302) == "/#{URI.encode_www_form(site.domain)}/settings/general"
    end
  end

  describe "POST /sites/:domain/make-public" do
    setup [:create_user, :log_in, :create_site]

    test "makes the site public", %{conn: conn, site: site} do
      conn = post(conn, "/sites/#{site.domain}/make-public")

      updated = Repo.get(Plausible.Site, site.id)
      assert updated.public

      assert redirected_to(conn, 302) ==
               "/#{URI.encode_www_form(site.domain)}/settings/visibility"
    end

    test "fails to make site public with insufficient permissions", %{conn: conn, user: user} do
      site = new_site()
      add_guest(site, user: user, role: :viewer)
      conn = post(conn, "/sites/#{site.domain}/make-public")
      assert conn.status == 404
      refute Repo.get(Plausible.Site, site.id).public
    end

    test "fails to make foreign site public", %{conn: my_conn, user: me} do
      _my_site = new_site(owner: me)
      other_user = new_user()
      other_site = new_site(owner: other_user)

      my_conn = post(my_conn, "/sites/#{other_site.domain}/make-public")
      assert my_conn.status == 404
      refute Repo.get(Plausible.Site, other_site.id).public
    end
  end

  describe "POST /sites/:domain/make-private" do
    setup [:create_user, :log_in, :create_site]

    test "makes the site private", %{conn: conn, site: site} do
      conn = post(conn, "/sites/#{site.domain}/make-private")

      updated = Repo.get(Plausible.Site, site.id)
      refute updated.public

      assert redirected_to(conn, 302) ==
               "/#{URI.encode_www_form(site.domain)}/settings/visibility"
    end
  end

  describe "DELETE /:domain" do
    setup [:create_user, :log_in, :create_site]

    test "deletes the site", %{conn: conn, user: user} do
      site = new_site(owner: user)
      insert(:google_auth, user: user, site: site)
      insert(:spike_notification, site: site)
      insert(:drop_notification, site: site)

      delete(conn, "/#{site.domain}")

      refute Repo.exists?(from(s in Plausible.Site, where: s.id == ^site.id))
    end

    test "fails to delete a site with insufficient permissions", %{conn: conn, user: user} do
      site = new_site()
      add_guest(site, user: user, role: :viewer)
      insert(:google_auth, user: user, site: site)
      insert(:spike_notification, site: site)

      conn = delete(conn, "/#{site.domain}")

      assert conn.status == 404
      assert Repo.exists?(from(s in Plausible.Site, where: s.id == ^site.id))
    end

    test "fails to delete a foreign site", %{conn: my_conn, user: me} do
      _my_site = new_site(owner: me)
      other_user = new_user()
      other_site = new_site(owner: other_user)

      insert(:google_auth, user: other_user, site: other_site)
      insert(:spike_notification, site: other_site)

      my_conn = delete(my_conn, "/#{other_site.domain}")
      assert my_conn.status == 404
      assert Repo.exists?(from(s in Plausible.Site, where: s.id == ^other_site.id))
    end
  end

  describe "PUT /:domain/settings/google" do
    setup [:create_user, :log_in, :create_site]

    test "updates google auth property", %{conn: conn, user: user, site: site} do
      insert(:google_auth, user: user, site: site)

      conn =
        put(conn, "/#{site.domain}/settings/google", %{
          "google_auth" => %{"property" => "some-new-property.com"}
        })

      updated_auth = Repo.one(Plausible.Site.GoogleAuth)
      assert updated_auth.property == "some-new-property.com"

      assert redirected_to(conn, 302) ==
               "/#{URI.encode_www_form(site.domain)}/settings/integrations"
    end
  end

  describe "DELETE /:domain/settings/google" do
    setup [:create_user, :log_in, :create_site]

    test "deletes associated google auth", %{conn: conn, user: user, site: site} do
      insert(:google_auth, user: user, site: site)
      conn = delete(conn, "/#{site.domain}/settings/google-search")

      refute Repo.exists?(Plausible.Site.GoogleAuth)

      assert redirected_to(conn, 302) ==
               "/#{URI.encode_www_form(site.domain)}/settings/integrations"
    end

    test "fails to delete associated google auth from the outside", %{
      conn: conn,
      user: user
    } do
      other_site = new_site()
      insert(:google_auth, user: user, site: other_site)
      conn = delete(conn, "/#{URI.encode_www_form(other_site.domain)}/settings/google-search")

      assert conn.status == 404
      assert Repo.exists?(Plausible.Site.GoogleAuth)
    end
  end

  describe "GET /:domain/settings/imports-exports" do
    setup [:create_user, :log_in, :create_site, :maybe_fake_minio]

    test "renders empty imports list", %{conn: conn, site: site} do
      conn = get(conn, "/#{site.domain}/settings/imports-exports")
      resp = html_response(conn, 200)

      assert text_of_attr(resp, ~s|a[href]|, "href") =~
               "https://accounts.google.com/o/oauth2/"

      assert resp =~ "Import Data"
      assert resp =~ "There are no imports yet"
      assert resp =~ "Export Data"
    end

    test "renders imports in import list", %{conn: conn, site: site} do
      _site_import1 = insert(:site_import, site: site, status: SiteImport.pending())
      _site_import2 = insert(:site_import, site: site, status: SiteImport.importing())

      site_import3 =
        insert(:site_import, label: "123456", site: site, status: SiteImport.completed())

      _site_import4 = insert(:site_import, site: site, status: SiteImport.failed())

      populate_stats(site, site_import3.id, [
        build(:imported_visitors, pageviews: 7777),
        build(:imported_visitors, pageviews: 2221)
      ])

      conn = get(conn, "/#{site.domain}/settings/imports-exports")
      resp = html_response(conn, 200)

      buttons = find(resp, ~s|a[data-method="delete"]|)
      assert length(buttons) == 4

      assert resp =~ "Google Analytics (123456)"
      assert resp =~ "9.9k"
    end

    test "disables import buttons when imports are at maximum", %{conn: conn, site: site} do
      insert_list(Plausible.Imported.max_complete_imports(), :site_import,
        site: site,
        status: SiteImport.completed()
      )

      conn = get(conn, "/#{site.domain}/settings/imports-exports")

      assert html_response(conn, 200) =~
               "Maximum of #{Plausible.Imported.max_complete_imports()} imports is reached."
    end

    test "considers older legacy imports when showing pageview count", %{conn: conn, site: site} do
      _site_import =
        insert(:site_import, site: site, legacy: true, status: SiteImport.completed())

      populate_stats(site, [
        build(:imported_visitors, pageviews: 7777),
        build(:imported_visitors, pageviews: 2221)
      ])

      conn = get(conn, "/#{site.domain}/settings/imports-exports")

      resp = html_response(conn, 200)

      assert resp =~ "9.9k"
    end

    test "disables import buttons when there's import in progress", %{conn: conn, site: site} do
      _site_import1 = insert(:site_import, site: site, status: SiteImport.completed())
      _site_import2 = insert(:site_import, site: site, status: SiteImport.importing())

      conn = get(conn, "/#{site.domain}/settings/imports-exports")
      assert html_response(conn, 200) =~ "No new imports can be started"
    end

    test "enables import buttons when all imports are in completed or failed state", %{
      conn: conn,
      site: site
    } do
      _site_import1 = insert(:site_import, site: site, status: SiteImport.completed())
      _site_import2 = insert(:site_import, site: site, status: SiteImport.failed())

      conn = get(conn, "/#{site.domain}/settings/imports-exports")
      refute html_response(conn, 200) =~ "No new imports can be started"
    end

    test "displays notice when import in progress is running for over 5 minutes", %{
      conn: conn,
      site: site
    } do
      six_minutes_ago = NaiveDateTime.add(NaiveDateTime.utc_now(), -360)

      _site_import1 = insert(:site_import, site: site, status: SiteImport.completed())

      _site_import2 =
        insert(:site_import,
          site: site,
          status: SiteImport.importing(),
          updated_at: six_minutes_ago
        )

      conn = get(conn, "/#{site.domain}/settings/imports-exports")
      response = html_response(conn, 200)
      assert response =~ "No new imports can be started"
      assert response =~ "The import process might be taking longer due to the amount of data"
      assert response =~ "and rate limiting enforced by Google Analytics"
    end

    test "displays CSV export button", %{conn: conn, site: site} do
      assert conn |> get("/#{site.domain}/settings/imports-exports") |> html_response(200) =~
               "Prepare download"
    end
  end

  describe "GET /:domain/settings/imports-exports when object storage is unreachable" do
    setup [:create_user, :log_in, :create_site]

    setup tags do
      if tags[:async] do
        raise "this test modifies application environment and can't be run asynchronously"
      end

      prev_env = Application.get_env(:ex_aws, :s3)
      new_env = Keyword.update!(prev_env, :port, fn prev_port -> prev_port + 1 end)
      Application.put_env(:ex_aws, :s3, new_env)
      on_exit(fn -> Application.put_env(:ex_aws, :s3, prev_env) end)
    end

    @tag capture_log: true, ee_only: true
    test "displays error message", %{conn: conn, site: site} do
      assert conn |> get("/#{site.domain}/settings/imports-exports") |> html_response(200) =~
               "Something went wrong when fetching exports"
    end
  end

  describe "GET /:domain/settings/integrations for self-hosting" do
    setup [:create_user, :log_in, :create_site]

    setup_patch_env(:google,
      client_id: nil,
      client_secret: nil,
      api_url: "https://www.googleapis.com"
    )

    test "display search console settings", %{conn: conn, site: site} do
      conn = get(conn, "/#{site.domain}/settings/integrations")
      resp = html_response(conn, 200)
      assert resp =~ "An extra step is needed"
      assert resp =~ "Google Search Console integration"
      assert resp =~ "google-integration"
    end

    @tag :ee_only
    test "renders looker studio integration section", %{conn: conn, site: site} do
      conn = get(conn, "/#{site.domain}/settings/integrations")
      resp = html_response(conn, 200)
      assert resp =~ "Google Looker Studio Connector"
    end

    @tag :ce_build_only
    test "does not render looker studio integration section", %{conn: conn, site: site} do
      conn = get(conn, "/#{site.domain}/settings/integrations")
      resp = html_response(conn, 200)
      refute resp =~ "Google Looker Studio Connector"
    end
  end

  describe "GET /:domain/integrations (search-console)" do
    setup [:create_user, :log_in, :create_site]

    setup_patch_env(:google, client_id: "some", api_url: "https://www.googleapis.com")

    setup %{site: site, user: user} = context do
      insert(:google_auth, user: user, site: site, property: "sc-domain:#{site.domain}")
      context
    end

    test "displays Continue with Google link", %{conn: conn, user: user} do
      site = new_site(domain: "notconnectedyet.example.com", owner: user)

      conn = get(conn, "/#{site.domain}/settings/integrations")
      resp = html_response(conn, 200)

      assert button = find(resp, "a#search-console-connect")
      assert text(button) == "Continue with Google"
      assert text_of_attr(button, "href") =~ "https://accounts.google.com/o/oauth2/v2/auth?"
      assert text_of_attr(button, "href") =~ "webmasters.readonly"
      refute text_of_attr(button, "href") =~ "analytics.readonly"
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

      conn = get(conn, "/#{site.domain}/settings/integrations")
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

      conn = get(conn, "/#{site.domain}/settings/integrations")
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

      conn = get(conn, "/#{site.domain}/settings/integrations")
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
          conn = get(conn, "/#{site.domain}/settings/integrations")
          resp = html_response(conn, 200)

          assert resp =~ "Something went wrong, but looks temporary"
          assert resp =~ "try re-linking your Google account"
        end)

      assert log =~ "Google Analytics: failed to list sites: :nxdomain"
    end
  end

  describe "PUT /:domain/settings/features/visibility/:setting" do
    def query_conn_with_some_url(context) do
      {:ok, Map.put(context, :conn_with_url, get(context.conn, "/some_parent_path"))}
    end

    setup [:create_user, :log_in, :query_conn_with_some_url]

    for {title, setting} <- %{
          "Goals" => :conversions_enabled,
          "Funnels" => :funnels_enabled,
          "Custom Properties" => :props_enabled
        } do
      test "can toggle #{title} with admin access", %{
        user: user,
        conn: conn0,
        conn_with_url: conn_with_url
      } do
        site = new_site()
        add_guest(site, user: user, role: :editor)

        conn =
          put(
            conn0,
            PlausibleWeb.Components.Site.Feature.target(
              site,
              unquote(setting),
              conn_with_url,
              false
            )
          )

        assert Phoenix.Flash.get(conn.assigns.flash, :success) ==
                 "#{unquote(title)} are now hidden from your dashboard"

        assert redirected_to(conn, 302) =~ "/some_parent_path"

        assert %{unquote(setting) => false} = Plausible.Sites.get_by_domain(site.domain)

        conn =
          put(
            conn0,
            PlausibleWeb.Components.Site.Feature.target(
              site,
              unquote(setting),
              conn_with_url,
              true
            )
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
        conn: conn0,
        conn_with_url: conn_with_url
      } do
        site = new_site()
        add_guest(site, user: user, role: :viewer)

        conn =
          put(
            conn0,
            PlausibleWeb.Components.Site.Feature.target(
              site,
              unquote(setting),
              conn_with_url,
              false
            )
          )

        assert conn.status == 404
        assert conn.halted
      end
    end

    test "setting feature visibility is idempotent", %{
      user: user,
      conn: conn0,
      conn_with_url: conn_with_url
    } do
      site = new_site()
      add_guest(site, user: user, role: :editor)

      setting = :funnels_enabled

      conn =
        put(
          conn0,
          PlausibleWeb.Components.Site.Feature.target(site, setting, conn_with_url, false)
        )

      assert %{^setting => false} = Plausible.Sites.get_by_domain(site.domain)
      assert redirected_to(conn, 302) =~ "/some_parent_path"

      conn =
        put(
          conn0,
          PlausibleWeb.Components.Site.Feature.target(site, setting, conn_with_url, false)
        )

      assert %{^setting => false} = Plausible.Sites.get_by_domain(site.domain)
      assert redirected_to(conn, 302) =~ "/some_parent_path"
    end
  end

  describe "POST /sites/:domain/weekly-report/enable" do
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

  describe "POST /sites/:domain/weekly-report/disable" do
    setup [:create_user, :log_in, :create_site]

    test "deletes the weekly report record", %{conn: conn, site: site} do
      insert(:weekly_report, site: site)

      post(conn, "/sites/#{site.domain}/weekly-report/disable")

      refute Repo.get_by(Plausible.Site.WeeklyReport, site_id: site.id)
    end

    test "fails to delete the weekly report record for a foreign site", %{conn: conn} do
      site = new_site()
      insert(:weekly_report, site: site)

      post(conn, "/sites/#{site.domain}/weekly-report/disable")

      assert Repo.get_by(Plausible.Site.WeeklyReport, site_id: site.id)
    end
  end

  describe "POST /sites/:domain/weekly-report/recipients" do
    setup [:create_user, :log_in, :create_site]

    test "adds a recipient to the weekly report", %{conn: conn, site: site} do
      insert(:weekly_report, site: site)

      post(conn, "/sites/#{site.domain}/weekly-report/recipients", recipient: "user@email.com")

      report = Repo.get_by(Plausible.Site.WeeklyReport, site_id: site.id)
      assert report.recipients == ["user@email.com"]
    end
  end

  describe "DELETE /sites/:domain/weekly-report/recipients/:recipient" do
    setup [:create_user, :log_in, :create_site]

    test "removes a recipient from the weekly report", %{conn: conn, site: site} do
      insert(:weekly_report, site: site, recipients: ["recipient@email.com"])

      delete(conn, "/sites/#{site.domain}/weekly-report/recipients/recipient@email.com")

      report = Repo.get_by(Plausible.Site.WeeklyReport, site_id: site.id)
      assert report.recipients == []
    end

    test "fails to remove a recipient from the weekly report in a foreign website", %{conn: conn} do
      site = new_site()
      insert(:weekly_report, site: site, recipients: ["recipient@email.com"])

      conn1 = delete(conn, "/sites/#{site.domain}/weekly-report/recipients/recipient@email.com")
      assert conn1.status == 404

      conn2 = delete(conn, "/sites/#{site.domain}/weekly-report/recipients/recipient%40email.com")
      assert conn2.status == 404

      report = Repo.get_by(Plausible.Site.WeeklyReport, site_id: site.id)
      assert [_] = report.recipients
    end
  end

  describe "POST /sites/:domain/monthly-report/enable" do
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

  describe "POST /sites/:domain/monthly-report/disable" do
    setup [:create_user, :log_in, :create_site]

    test "deletes the monthly report record", %{conn: conn, site: site} do
      insert(:monthly_report, site: site)

      post(conn, "/sites/#{site.domain}/monthly-report/disable")

      refute Repo.get_by(Plausible.Site.MonthlyReport, site_id: site.id)
    end
  end

  describe "POST /sites/:domain/monthly-report/recipients" do
    setup [:create_user, :log_in, :create_site]

    test "adds a recipient to the monthly report", %{conn: conn, site: site} do
      insert(:monthly_report, site: site)

      post(conn, "/sites/#{site.domain}/monthly-report/recipients", recipient: "user@email.com")

      report = Repo.get_by(Plausible.Site.MonthlyReport, site_id: site.id)
      assert report.recipients == ["user@email.com"]
    end
  end

  describe "DELETE /sites/:domain/monthly-report/recipients/:recipient" do
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
      site = new_site()
      insert(:monthly_report, site: site, recipients: ["recipient@email.com"])

      conn1 = delete(conn, "/sites/#{site.domain}/monthly-report/recipients/recipient@email.com")
      assert conn1.status == 404

      conn2 =
        delete(conn, "/sites/#{site.domain}/monthly-report/recipients/recipient%40email.com")

      assert conn2.status == 404

      report = Repo.get_by(Plausible.Site.MonthlyReport, site_id: site.id)
      assert [_] = report.recipients
    end
  end

  for type <- [:spike, :drop] do
    describe "POST /sites/:domain/traffic-change-notification/#{type}/enable" do
      setup [:create_user, :log_in, :create_site]

      test "creates a #{type} notification record with the user email", %{
        conn: conn,
        site: site,
        user: user
      } do
        post(conn, "/sites/#{site.domain}/traffic-change-notification/#{unquote(type)}/enable")

        notification =
          Repo.get_by(Plausible.Site.TrafficChangeNotification,
            site_id: site.id,
            type: unquote(type)
          )

        assert notification.recipients == [user.email]
      end

      test "does not allow duplicate #{type} notification to be created", %{
        conn: conn,
        site: site
      } do
        post(conn, "/sites/#{site.domain}/traffic-change-notification/#{unquote(type)}/enable")
        post(conn, "/sites/#{site.domain}/traffic-change-notification/#{unquote(type)}/enable")

        assert Repo.aggregate(
                 from(s in Plausible.Site.TrafficChangeNotification,
                   where: s.site_id == ^site.id and s.type == ^unquote(type)
                 ),
                 :count
               ) == 1
      end
    end

    describe "POST /sites/:domain/traffic-change-notification/#{type}/disable" do
      setup [:create_user, :log_in, :create_site]

      test "deletes the #{type} notification record", %{conn: conn, site: site} do
        insert(:"#{unquote(type)}_notification", site: site)

        post(conn, "/sites/#{site.domain}/traffic-change-notification/#{unquote(type)}/disable")

        refute Repo.get_by(Plausible.Site.TrafficChangeNotification, site_id: site.id)
      end
    end

    describe "PUT /sites/:domain/traffic-change-notification/#{type}" do
      setup [:create_user, :log_in, :create_site]

      test "updates #{type} notification threshold", %{conn: conn, site: site} do
        insert(:"#{unquote(type)}_notification", site: site, threshold: 10)

        put(conn, "/sites/#{site.domain}/traffic-change-notification/#{unquote(type)}", %{
          "traffic_change_notification" => %{"threshold" => "15"}
        })

        notification =
          Repo.get_by(Plausible.Site.TrafficChangeNotification,
            site_id: site.id,
            type: unquote(type)
          )

        assert notification.threshold == 15
      end
    end

    describe "POST /sites/:domain/traffic-change-notification/#{type}/recipients" do
      setup [:create_user, :log_in, :create_site]

      test "adds a recipient to the #{type} notification", %{conn: conn, site: site} do
        insert(:"#{unquote(type)}_notification", site: site)

        post(
          conn,
          "/sites/#{site.domain}/traffic-change-notification/#{unquote(type)}/recipients",
          recipient: "user@email.com"
        )

        report =
          Repo.get_by(Plausible.Site.TrafficChangeNotification,
            site_id: site.id,
            type: unquote(type)
          )

        assert report.recipients == ["user@email.com"]
      end
    end

    describe "DELETE /sites/:domain/traffic-change-notification/#{type}/recipients/:recipient" do
      setup [:create_user, :log_in, :create_site]

      test "removes a recipient from the #{type} notification", %{conn: conn, site: site} do
        insert(:"#{unquote(type)}_notification", site: site, recipients: ["recipient@email.com"])

        delete(
          conn,
          "/sites/#{site.domain}/traffic-change-notification/#{unquote(type)}/recipients/recipient@email.com"
        )

        report =
          Repo.get_by(Plausible.Site.TrafficChangeNotification,
            site_id: site.id,
            type: unquote(type)
          )

        assert report.recipients == []
      end

      test "fails to remove a recipient from the #{type} notification in a foreign website", %{
        conn: conn
      } do
        site = new_site()
        insert(:"#{unquote(type)}_notification", site: site, recipients: ["recipient@email.com"])

        conn =
          delete(
            conn,
            "/sites/#{site.domain}/traffic-change-notification/#{unquote(type)}/recipients/recipient@email.com"
          )

        assert conn.status == 404

        conn =
          delete(
            conn,
            "/sites/#{site.domain}/traffic-change-notification/recipients/#{unquote(type)}/recipient%40email.com"
          )

        assert conn.status == 404

        report =
          Repo.get_by(Plausible.Site.TrafficChangeNotification,
            site_id: site.id,
            type: unquote(type)
          )

        assert [_] = report.recipients
      end
    end
  end

  describe "GET /sites/:domain/shared-links/new" do
    setup [:create_user, :log_in, :create_site]

    test "shows form for new shared link", %{conn: conn, site: site} do
      conn = get(conn, "/sites/#{site.domain}/shared-links/new")

      assert html_response(conn, 200) =~ "New Shared Link"
    end
  end

  describe "POST /sites/:domain/shared-links" do
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

  describe "GET /sites/:domain/shared-links/edit" do
    setup [:create_user, :log_in, :create_site]

    test "shows form to edit shared link", %{conn: conn, site: site} do
      link = insert(:shared_link, site: site)
      conn = get(conn, "/sites/#{site.domain}/shared-links/#{link.slug}/edit")

      assert html_response(conn, 200) =~ "Edit Shared Link"
    end
  end

  describe "PUT /sites/:domain/shared-links/:slug" do
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

  describe "DELETE /sites/:domain/shared-links/:slug" do
    setup [:create_user, :log_in, :create_site]

    test "deletes shared link", %{conn: conn, site: site} do
      link = insert(:shared_link, site: site)

      conn = delete(conn, "/sites/#{site.domain}/shared-links/#{link.slug}")

      refute Repo.one(Plausible.Site.SharedLink)
      assert redirected_to(conn, 302) =~ "/#{URI.encode_www_form(site.domain)}/settings"
      assert Phoenix.Flash.get(conn.assigns.flash, :success) == "Shared Link deleted"
    end

    test "fails to delete shared link from the outside", %{conn: conn, site: site} do
      other_site = insert(:site)
      link = insert(:shared_link, site: other_site)

      conn = delete(conn, "/sites/#{site.domain}/shared-links/#{link.slug}")

      assert Repo.one(Plausible.Site.SharedLink)
      assert html_response(conn, 404)
    end
  end

  describe "DELETE /:domain/settings/:forget_import/:import_id" do
    setup [:create_user, :log_in, :create_site, :create_legacy_site_import]

    test "removes site import, associated data and cancels oban job for a particular import", %{
      conn: conn,
      user: user,
      site: site
    } do
      {:ok, job} =
        Plausible.Imported.NoopImporter.new_import(
          site,
          user,
          start_date: ~D[2022-01-01],
          end_date: Timex.today()
        )

      %{args: %{import_id: import_id}} = job

      # legacy stats
      populate_stats(site, [
        build(:imported_visitors, pageviews: 12)
      ])

      populate_stats(site, import_id, [
        build(:imported_visitors, pageviews: 10)
      ])

      imports = Plausible.Imported.list_all_imports(site)

      assert Enum.find(imports, &(&1.id == import_id))

      assert eventually(fn ->
               count = Plausible.Stats.Clickhouse.imported_pageview_count(site)
               {count == 22, count}
             end)

      delete(conn, "/#{site.domain}/settings/forget-import/#{import_id}")

      assert eventually(fn ->
               count = Plausible.Stats.Clickhouse.imported_pageview_count(site)
               {count == 12, count}
             end)

      assert Repo.reload(job).state == "cancelled"
    end

    test "removes all legacy site import data when instructed", %{
      conn: conn,
      site: site,
      site_import: legacy_site_import
    } do
      other_site_import = insert(:site_import, site: site)

      # legacy stats
      populate_stats(site, [
        build(:imported_visitors, pageviews: 12)
      ])

      populate_stats(site, other_site_import.id, [
        build(:imported_visitors, pageviews: 10)
      ])

      assert eventually(fn ->
               count = Plausible.Stats.Clickhouse.imported_pageview_count(site)
               {count == 22, count}
             end)

      delete(conn, "/#{site.domain}/settings/forget-import/#{legacy_site_import.id}")

      assert eventually(fn ->
               count = Plausible.Stats.Clickhouse.imported_pageview_count(site)
               {count == 10, count}
             end)
    end
  end

  describe "DELETE /:domain/settings/forget_imported" do
    setup [:create_user, :log_in, :create_site]

    test "removes actual imported data from Clickhouse", %{conn: conn, user: user, site: site} do
      Plausible.Imported.NoopImporter.new_import(
        site,
        user,
        start_date: ~D[2022-01-01],
        end_date: Timex.today()
      )

      populate_stats(site, [
        build(:imported_visitors, pageviews: 10)
      ])

      delete(conn, "/#{site.domain}/settings/forget-imported")

      assert eventually(fn ->
               count = Plausible.Stats.Clickhouse.imported_pageview_count(site)
               {count == 0, count}
             end)
    end

    test "cancels Oban job if it exists", %{conn: conn, user: user, site: site} do
      {:ok, job} =
        Plausible.Imported.NoopImporter.new_import(
          site,
          user,
          start_date: ~D[2022-01-01],
          end_date: Timex.today()
        )

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

      assert resp =~ "Site Domain"
      assert resp =~ "Change Domain"
      assert resp =~ Routes.site_path(conn, :change_domain, site.domain)
    end

    test "domain change form renders", %{conn: conn, site: site} do
      conn = get(conn, Routes.site_path(conn, :change_domain, site.domain))
      resp = html_response(conn, 200)
      assert resp =~ Routes.site_path(conn, :change_domain_submit, site.domain)

      assert text(resp) =~
               "Once you change your domain, you must update Plausible Installation on your site within 72 hours"
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

    test "domain change successful form submission redirects to installation", %{
      conn: conn,
      site: site
    } do
      original_domain = site.domain
      new_domain = "â-example.com"

      conn =
        put(conn, Routes.site_path(conn, :change_domain_submit, site.domain), %{
          "site" => %{"domain" => new_domain}
        })

      assert redirected_to(conn) ==
               Routes.site_path(conn, :installation, new_domain,
                 flow: PlausibleWeb.Flows.domain_change()
               )

      site = Repo.reload!(site)
      assert site.domain == new_domain
      assert site.domain_changed_from == original_domain
    end
  end

  describe "reset stats" do
    setup [:create_user, :log_in, :create_site]

    test "resets native_stats_start_date", %{conn: conn, site: site} do
      Plausible.Site.set_stats_start_date(site, ~D[2023-01-01])
      |> Repo.update!()

      delete(conn, Routes.site_path(conn, :reset_stats, site.domain))

      assert Repo.reload(site).stats_start_date == nil
    end
  end
end
