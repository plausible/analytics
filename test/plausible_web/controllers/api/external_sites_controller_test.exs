defmodule PlausibleWeb.Api.ExternalSitesControllerTest do
  use Plausible
  use PlausibleWeb.ConnCase, async: false
  use Plausible.Repo
  use Plausible.Teams.Test
  use Bamboo.Test

  on_ee do
    setup :create_user

    setup %{conn: conn, user: user} do
      api_key = insert(:api_key, user: user, scopes: ["sites:provision:*"])
      conn = Plug.Conn.put_req_header(conn, "authorization", "Bearer #{api_key.key}")
      {:ok, api_key: api_key, conn: conn}
    end

    describe "GET /api/v1/sites/teams" do
      test "shows empty list when user is not a member of any team", %{conn: conn} do
        conn = get(conn, "/api/v1/sites/teams")

        assert json_response(conn, 200) == %{
                 "teams" => [],
                 "meta" => %{
                   "before" => nil,
                   "after" => nil,
                   "limit" => 100
                 }
               }
      end

      test "shows list of teams user is a member of with api availability reflecting team state",
           %{conn: conn, user: user} do
        user |> subscribe_to_growth_plan()

        personal_team = team_of(user)

        owner1 =
          new_user(
            trial_expiry_date: Date.add(Date.utc_today(), -1),
            team: [name: "Team Without Stats API"]
          )
          |> subscribe_to_enterprise_plan(features: [])

        team_without_stats = owner1 |> team_of() |> Plausible.Teams.complete_setup()
        add_member(team_without_stats, user: user, role: :editor)
        owner2 = new_user(team: [name: "Team With Stats API"])
        team_with_stats = owner2 |> team_of() |> Plausible.Teams.complete_setup()
        add_member(team_with_stats, user: user, role: :owner)

        conn = get(conn, "/api/v1/sites/teams")

        assert json_response(conn, 200) == %{
                 "teams" => [
                   %{
                     "id" => team_with_stats.identifier,
                     "name" => "Team With Stats API",
                     "api_available" => true
                   },
                   %{
                     "id" => team_without_stats.identifier,
                     "name" => "Team Without Stats API",
                     "api_available" => false
                   },
                   %{
                     "id" => personal_team.identifier,
                     "name" => "My Personal Sites",
                     "api_available" => false
                   }
                 ],
                 "meta" => %{
                   "before" => nil,
                   "after" => nil,
                   "limit" => 100
                 }
               }
      end
    end

    describe "POST /api/v1/sites" do
      test "can create a site", %{conn: conn} do
        conn =
          post(conn, "/api/v1/sites", %{
            "domain" => "some-site.domain",
            "timezone" => "Europe/Tallinn"
          })

        assert json_response(conn, 200) == %{
                 "domain" => "some-site.domain",
                 "timezone" => "Europe/Tallinn"
               }
      end

      test "can't create site in a team where not permitted to", %{conn: conn, user: user} do
        owner = new_user() |> subscribe_to_growth_plan()
        team = owner |> team_of() |> Plausible.Teams.complete_setup()
        add_member(team, user: user, role: :viewer)

        conn =
          post(conn, "/api/v1/sites", %{
            "team_id" => team.identifier,
            "domain" => "some-site.domain",
            "timezone" => "Europe/Tallinn"
          })

        assert json_response(conn, 403) == %{
                 "error" => "You can't add sites to the selected team."
               }
      end

      test "can create a site under a specific team if permitted", %{conn: conn, user: user} do
        _site = new_site(owner: user)

        owner = new_user() |> subscribe_to_growth_plan()
        team = owner |> team_of() |> Plausible.Teams.complete_setup()
        add_member(team, user: user, role: :owner)

        conn =
          post(conn, "/api/v1/sites", %{
            "team_id" => team.identifier,
            "domain" => "some-site.domain",
            "timezone" => "Europe/Tallinn"
          })

        assert json_response(conn, 200) == %{
                 "domain" => "some-site.domain",
                 "timezone" => "Europe/Tallinn"
               }

        assert Repo.get_by(Plausible.Site, domain: "some-site.domain").team_id == team.id
      end

      test "timezone is validated", %{conn: conn} do
        conn =
          post(conn, "/api/v1/sites", %{
            "domain" => "some-site.domain",
            "timezone" => "d"
          })

        assert json_response(conn, 400) == %{
                 "error" => "timezone: is invalid"
               }
      end

      test "timezone defaults to Etc/UTC", %{conn: conn} do
        conn =
          post(conn, "/api/v1/sites", %{
            "domain" => "some-site.domain"
          })

        assert json_response(conn, 200) == %{
                 "domain" => "some-site.domain",
                 "timezone" => "Etc/UTC"
               }
      end

      test "domain is required", %{conn: conn} do
        conn = post(conn, "/api/v1/sites", %{})

        assert json_response(conn, 400) == %{
                 "error" => "domain: can't be blank"
               }
      end

      test "accepts international domain names", %{conn: conn} do
        ["müllers-café.test", "音乐.cn", "до.101домен.рф/pages"]
        |> Enum.each(fn idn_domain ->
          conn = post(conn, "/api/v1/sites", %{"domain" => idn_domain})
          assert %{"domain" => ^idn_domain} = json_response(conn, 200)
        end)
      end

      test "validates uri breaking domains", %{conn: conn} do
        ["quero:café.test", "h&llo.test", "iamnotsur&about?this.com"]
        |> Enum.each(fn bad_domain ->
          conn = post(conn, "/api/v1/sites", %{"domain" => bad_domain})

          assert %{"error" => error} = json_response(conn, 400)
          assert error =~ "domain: must not contain URI reserved characters"
        end)
      end

      test "does not allow creating more sites than the limit", %{conn: conn, user: user} do
        for _ <- 1..10, do: new_site(owner: user)

        conn =
          post(conn, "/api/v1/sites", %{
            "domain" => "some-site.domain",
            "timezone" => "Europe/Tallinn"
          })

        assert json_response(conn, 402) == %{
                 "error" =>
                   "Your account has reached the limit of 10 sites. To unlock more sites, please upgrade your subscription."
               }
      end

      test "cannot access with a bad API key scope", %{conn: conn, user: user} do
        api_key = insert(:api_key, user: user, scopes: ["stats:read:*"])

        conn =
          conn
          |> Plug.Conn.put_req_header("authorization", "Bearer #{api_key.key}")
          |> post("/api/v1/sites", %{"site" => %{"domain" => "domain.com"}})

        assert json_response(conn, 401) == %{
                 "error" =>
                   "Invalid API key. Please make sure you're using a valid API key with access to the resource you've requested."
               }
      end
    end

    describe "DELETE /api/v1/sites/:site_id" do
      setup :create_site

      test "delete a site by its domain", %{conn: conn, site: site} do
        conn = delete(conn, "/api/v1/sites/" <> site.domain)

        assert json_response(conn, 200) == %{"deleted" => true}
      end

      test "delete a site by its old domain after domain change", %{conn: conn, site: site} do
        old_domain = site.domain
        new_domain = "new.example.com"

        Plausible.Site.Domain.change(site, new_domain)

        conn = delete(conn, "/api/v1/sites/" <> old_domain)

        assert json_response(conn, 200) == %{"deleted" => true}
      end

      test "is 404 when site cannot be found", %{conn: conn} do
        conn = delete(conn, "/api/v1/sites/foobar.baz")

        assert json_response(conn, 404) == %{"error" => "Site could not be found"}
      end

      test "cannot delete a site that the user does not own", %{conn: conn, user: user} do
        site = new_site()
        add_guest(site, user: user, role: :editor)
        conn = delete(conn, "/api/v1/sites/" <> site.domain)

        assert json_response(conn, 404) == %{"error" => "Site could not be found"}
      end

      test "cannot access with a bad API key scope", %{conn: conn, site: site, user: user} do
        api_key = insert(:api_key, user: user, scopes: ["stats:read:*"])

        conn =
          conn
          |> Plug.Conn.put_req_header("authorization", "Bearer #{api_key.key}")
          |> delete("/api/v1/sites/" <> site.domain)

        assert json_response(conn, 401) == %{
                 "error" =>
                   "Invalid API key. Please make sure you're using a valid API key with access to the resource you've requested."
               }
      end
    end

    describe "PUT /api/v1/sites/shared-links" do
      setup :create_site

      test "can add a shared link to a site", %{conn: conn, site: site} do
        conn =
          put(conn, "/api/v1/sites/shared-links", %{
            site_id: site.domain,
            name: "WordPress"
          })

        res = json_response(conn, 200)
        assert res["name"] == "WordPress"
        assert String.starts_with?(res["url"], "http://")
      end

      test "can add a shared link to a site using the old site id after domain change", %{
        conn: conn,
        site: site
      } do
        old_domain = site.domain
        new_domain = "new.example.com"

        Plausible.Site.Domain.change(site, new_domain)

        conn =
          put(conn, "/api/v1/sites/shared-links", %{
            site_id: old_domain,
            name: "WordPress"
          })

        res = json_response(conn, 200)
        assert res["name"] == "WordPress"
        assert String.starts_with?(res["url"], "http://")
      end

      test "is idempotent find or create op", %{conn: conn, site: site} do
        conn =
          put(conn, "/api/v1/sites/shared-links", %{
            site_id: site.domain,
            name: "WordPress"
          })

        %{"url" => url} = json_response(conn, 200)

        conn =
          put(conn, "/api/v1/sites/shared-links", %{
            site_id: site.domain,
            name: "WordPress"
          })

        assert %{"url" => ^url} = json_response(conn, 200)
      end

      test "returns 400 when site id missing", %{conn: conn} do
        conn =
          put(conn, "/api/v1/sites/shared-links", %{
            name: "WordPress"
          })

        res = json_response(conn, 400)
        assert res["error"] == "Parameter `site_id` is required to create a shared link"
      end

      test "returns 404 when site id is non existent", %{conn: conn} do
        conn =
          put(conn, "/api/v1/sites/shared-links", %{
            name: "WordPress",
            site_id: "bad"
          })

        res = json_response(conn, 404)
        assert res["error"] == "Site could not be found"
      end

      test "returns 404 when api key owner does not have permissions to create a shared link", %{
        conn: conn,
        user: user
      } do
        site = new_site()

        add_guest(site, user: user, role: :viewer)

        conn =
          put(conn, "/api/v1/sites/shared-links", %{
            site_id: site.domain,
            name: "WordPress"
          })

        res = json_response(conn, 404)
        assert res["error"] == "Site could not be found"
      end
    end

    describe "PUT /api/v1/sites/goals" do
      setup :create_site

      test "can add a goal as event to a site", %{conn: conn, site: site} do
        conn =
          put(conn, "/api/v1/sites/goals", %{
            site_id: site.domain,
            goal_type: "event",
            event_name: "Signup"
          })

        res = json_response(conn, 200)

        assert res["goal_type"] == "event"
        assert res["display_name"] == "Signup"
        assert res["event_name"] == "Signup"
        assert res["domain"] == site.domain
      end

      test "can add a goal as page to a site", %{conn: conn, site: site} do
        conn =
          put(conn, "/api/v1/sites/goals", %{
            site_id: site.domain,
            goal_type: "page",
            page_path: "/signup"
          })

        res = json_response(conn, 200)
        assert res["goal_type"] == "page"
        assert res["page_path"] == "/signup"
        assert res["display_name"] == "Visit /signup"
        assert res["domain"] == site.domain
      end

      test "can add a goal using old site_id after domain change", %{conn: conn, site: site} do
        old_domain = site.domain
        new_domain = "new.example.com"

        Plausible.Site.Domain.change(site, new_domain)

        conn =
          put(conn, "/api/v1/sites/goals", %{
            site_id: old_domain,
            goal_type: "event",
            event_name: "Signup"
          })

        res = json_response(conn, 200)
        assert res["goal_type"] == "event"
        assert res["event_name"] == "Signup"
        assert res["display_name"] == "Signup"
        assert res["domain"] == new_domain
      end

      test "can add a goal as event with display name", %{conn: conn, site: site} do
        conn =
          put(conn, "/api/v1/sites/goals", %{
            site_id: site.domain,
            goal_type: "event",
            event_name: "Signup",
            display_name: "Customer Acquired"
          })

        res = json_response(conn, 200)
        assert res["goal_type"] == "event"
        assert res["event_name"] == "Signup"
        assert res["display_name"] == "Customer Acquired"
        assert res["domain"] == site.domain
      end

      test "can add a goal as page with display name", %{conn: conn, site: site} do
        conn =
          put(conn, "/api/v1/sites/goals", %{
            site_id: site.domain,
            goal_type: "page",
            page_path: "/foo",
            display_name: "Visit the foo page"
          })

        res = json_response(conn, 200)
        assert res["goal_type"] == "page"
        assert res["display_name"] == "Visit the foo page"
        assert res["page_path"] == "/foo"
        assert res["domain"] == site.domain
      end

      test "is idempotent find or create op", %{conn: conn, site: site} do
        conn =
          put(conn, "/api/v1/sites/goals", %{
            site_id: site.domain,
            goal_type: "event",
            event_name: "Signup"
          })

        %{"id" => goal_id} = json_response(conn, 200)

        conn =
          put(conn, "/api/v1/sites/goals", %{
            site_id: site.domain,
            goal_type: "event",
            event_name: "Signup"
          })

        assert %{"id" => ^goal_id} = json_response(conn, 200)
      end

      test "returns 400 when site id missing", %{conn: conn} do
        conn =
          put(conn, "/api/v1/sites/goals", %{
            goal_type: "event",
            event_name: "Signup"
          })

        res = json_response(conn, 400)
        assert res["error"] == "Parameter `site_id` is required to create a goal"
      end

      test "returns 404 when site id is non existent", %{conn: conn} do
        conn =
          put(conn, "/api/v1/sites/goals", %{
            goal_type: "event",
            event_name: "Signup",
            site_id: "bad"
          })

        res = json_response(conn, 404)
        assert res["error"] == "Site could not be found"
      end

      test "returns 404 when api key owner does not have permissions to create a goal", %{
        conn: conn,
        user: user
      } do
        site = new_site()

        add_guest(site, user: user, role: :viewer)

        conn =
          put(conn, "/api/v1/sites/goals", %{
            site_id: site.domain,
            goal_type: "event",
            event_name: "Signup"
          })

        res = json_response(conn, 404)
        assert res["error"] == "Site could not be found"
      end

      test "returns 400 when goal type missing", %{conn: conn, site: site} do
        conn =
          put(conn, "/api/v1/sites/goals", %{
            site_id: site.domain,
            event_name: "Signup"
          })

        res = json_response(conn, 400)
        assert res["error"] == "Parameter `goal_type` is required to create a goal"
      end

      test "returns 400 when goal event name missing", %{conn: conn, site: site} do
        conn =
          put(conn, "/api/v1/sites/goals", %{
            site_id: site.domain,
            goal_type: "event"
          })

        res = json_response(conn, 400)
        assert res["error"] == "Parameter `event_name` is required to create a goal"
      end

      test "returns 400 when goal page path missing", %{conn: conn, site: site} do
        conn =
          put(conn, "/api/v1/sites/goals", %{
            site_id: site.domain,
            goal_type: "page"
          })

        res = json_response(conn, 400)
        assert res["error"] == "Parameter `page_path` is required to create a goal"
      end
    end

    describe "DELETE /api/v1/sites/goals/:goal_id" do
      setup :create_site

      test "delete a goal by its id", %{conn: conn, site: site} do
        conn =
          put(conn, "/api/v1/sites/goals", %{
            site_id: site.domain,
            goal_type: "event",
            event_name: "Signup"
          })

        %{"id" => goal_id} = json_response(conn, 200)

        conn =
          delete(conn, "/api/v1/sites/goals/#{goal_id}", %{
            site_id: site.domain
          })

        assert json_response(conn, 200) == %{"deleted" => true}
      end

      test "delete a goal using old site_id after domain change", %{conn: conn, site: site} do
        old_domain = site.domain
        new_domain = "new.example.com"

        Plausible.Site.Domain.change(site, new_domain)

        conn =
          put(conn, "/api/v1/sites/goals", %{
            site_id: new_domain,
            goal_type: "event",
            event_name: "Signup"
          })

        %{"id" => goal_id} = json_response(conn, 200)

        conn =
          delete(conn, "/api/v1/sites/goals/#{goal_id}", %{
            site_id: old_domain
          })

        assert json_response(conn, 200) == %{"deleted" => true}
      end

      test "is 404 when goal cannot be found", %{conn: conn, site: site} do
        conn =
          delete(conn, "/api/v1/sites/goals/0", %{
            site_id: site.domain
          })

        assert json_response(conn, 404) == %{"error" => "Goal could not be found"}
      end

      test "cannot delete a goal belongs to a site that the user does not own", %{
        conn: conn,
        user: user
      } do
        site = new_site()
        add_guest(site, user: user, role: :viewer)

        conn =
          delete(conn, "/api/v1/sites/goals/1", %{
            site_id: site.domain
          })

        assert json_response(conn, 404) == %{"error" => "Site could not be found"}
      end

      test "cannot access with a bad API key scope", %{conn: conn, site: site, user: user} do
        api_key = insert(:api_key, user: user, scopes: ["stats:read:*"])

        conn =
          conn
          |> Plug.Conn.put_req_header("authorization", "Bearer #{api_key.key}")

        conn =
          delete(conn, "/api/v1/sites/goals/1", %{
            site_id: site.domain
          })

        assert json_response(conn, 401) == %{
                 "error" =>
                   "Invalid API key. Please make sure you're using a valid API key with access to the resource you've requested."
               }
      end
    end

    describe "GET /api/v1/sites" do
      test "returns empty when there are no sites for user", %{conn: conn} do
        conn = get(conn, "/api/v1/sites")

        assert json_response(conn, 200) == %{
                 "sites" => [],
                 "meta" => %{
                   "before" => nil,
                   "after" => nil,
                   "limit" => 100
                 }
               }
      end

      test "returns sites when present", %{conn: conn, user: user} do
        site1 = new_site(owner: user)
        site2 = new_site(owner: user)

        _unrelated_site = new_site()

        conn = get(conn, "/api/v1/sites")

        assert json_response(conn, 200) == %{
                 "sites" => [
                   %{"domain" => site2.domain, "timezone" => site2.timezone},
                   %{"domain" => site1.domain, "timezone" => site1.timezone}
                 ],
                 "meta" => %{
                   "before" => nil,
                   "after" => nil,
                   "limit" => 100
                 }
               }
      end

      test "returns sites where user is only a viewer", %{conn: conn, user: user} do
        %{domain: owned_site_domain} = new_site(owner: user)
        other_site = %{domain: other_site_domain} = new_site()
        add_guest(other_site, user: user, role: :viewer)

        conn = get(conn, "/api/v1/sites")

        assert %{
                 "sites" => [
                   %{"domain" => ^other_site_domain},
                   %{"domain" => ^owned_site_domain}
                 ]
               } = json_response(conn, 200)
      end

      test "returns sites scoped to a given team for full memberships", %{conn: conn, user: user} do
        _owned_site = new_site(owner: user)
        other_site = new_site()
        add_guest(other_site, user: user, role: :viewer)
        other_team_site = new_site()
        add_member(other_team_site.team, user: user, role: :viewer)

        conn = get(conn, "/api/v1/sites?team_id=" <> other_team_site.team.identifier)

        assert_matches %{
                         "sites" => [
                           %{"domain" => ^other_team_site.domain}
                         ]
                       } = json_response(conn, 200)
      end

      test "handles pagination correctly", %{conn: conn, user: user} do
        [
          %{domain: site1_domain},
          %{domain: site2_domain},
          %{domain: site3_domain}
        ] = for _ <- 1..3, do: new_site(owner: user)

        conn1 = get(conn, "/api/v1/sites?limit=2")

        assert %{
                 "sites" => [
                   %{"domain" => ^site3_domain},
                   %{"domain" => ^site2_domain}
                 ],
                 "meta" => %{
                   "before" => nil,
                   "after" => after_cursor,
                   "limit" => 2
                 }
               } = json_response(conn1, 200)

        conn2 = get(conn, "/api/v1/sites?limit=2&after=" <> after_cursor)

        assert %{
                 "sites" => [
                   %{"domain" => ^site1_domain}
                 ],
                 "meta" => %{
                   "before" => before_cursor,
                   "after" => nil,
                   "limit" => 2
                 }
               } = json_response(conn2, 200)

        assert is_binary(before_cursor)
      end

      test "lists sites for user with read-only scope", %{conn: conn, user: user} do
        %{domain: site_domain} = new_site(owner: user)
        api_key = insert(:api_key, user: user, scopes: ["stats:read:*"])

        conn =
          conn
          |> Plug.Conn.put_req_header("authorization", "Bearer #{api_key.key}")
          |> get("/api/v1/sites")

        assert %{"sites" => [%{"domain" => ^site_domain}]} = json_response(conn, 200)
      end
    end

    describe "GET /api/v1/sites/guests" do
      test "returns empty when there are no guests for site", %{conn: conn, user: user} do
        site = new_site(owner: user)
        conn = get(conn, "/api/v1/sites/guests?site_id=#{site.domain}")

        assert json_response(conn, 200) == %{
                 "guests" => [],
                 "meta" => %{
                   "before" => nil,
                   "after" => nil,
                   "limit" => 100
                 }
               }
      end

      test "returns guests when present", %{conn: conn, user: user} do
        site = new_site(owner: user)

        guest1 = add_guest(site, site: site, role: :editor)
        guest2 = add_guest(site, site: site, role: :viewer)
        guest3 = invite_guest(site, "third@example.com", inviter: user, role: :viewer)

        conn = get(conn, "/api/v1/sites/guests?site_id=#{site.domain}")

        assert json_response(conn, 200) == %{
                 "guests" => [
                   %{"email" => guest2.email, "status" => "accepted", "role" => "viewer"},
                   %{"email" => guest1.email, "status" => "accepted", "role" => "editor"},
                   %{
                     "email" => guest3.team_invitation.email,
                     "status" => "invited",
                     "role" => "viewer"
                   }
                 ],
                 "meta" => %{
                   "before" => nil,
                   "after" => nil,
                   "limit" => 100
                 }
               }
      end

      test "returns guests paginated", %{conn: conn, user: user} do
        site = new_site(owner: user)

        %{email: guest1_email} = add_guest(site, site: site, role: :editor)
        %{email: guest2_email} = add_guest(site, site: site, role: :viewer)
        invite_guest(site, "third@example.com", inviter: user, role: :viewer)

        conn1 = get(conn, "/api/v1/sites/guests?site_id=#{site.domain}&limit=2")

        assert %{
                 "guests" => [
                   %{"email" => ^guest2_email, "status" => "accepted", "role" => "viewer"},
                   %{"email" => ^guest1_email, "status" => "accepted", "role" => "editor"}
                 ],
                 "meta" => %{
                   "before" => nil,
                   "after" => after_cursor,
                   "limit" => 2
                 }
               } = json_response(conn1, 200)

        conn2 =
          get(
            conn,
            "/api/v1/sites/guests?site_id=#{site.domain}&limit=2&after=#{after_cursor}"
          )

        assert %{
                 "guests" => [
                   %{
                     "email" => "third@example.com",
                     "status" => "invited",
                     "role" => "viewer"
                   }
                 ],
                 "meta" => %{
                   "before" => before_cursor,
                   "after" => nil,
                   "limit" => 2
                 }
               } =
                 json_response(conn2, 200)

        assert is_binary(before_cursor)
      end
    end

    describe "PUT /api/v1/sites/guests" do
      test "creates new invitation", %{conn: conn, user: user} do
        site = new_site(owner: user)

        conn =
          put(conn, "/api/v1/sites/guests?site_id=#{site.domain}", %{
            "role" => "viewer",
            "email" => "test@example.com"
          })

        assert json_response(conn, 200) == %{
                 "status" => "invited",
                 "email" => "test@example.com",
                 "role" => "viewer"
               }

        assert_email_delivered_with(
          to: [nil: "test@example.com"],
          subject: ~r/You've been invited to #{site.domain}/
        )
      end

      test "is idempotent", %{conn: conn, user: user} do
        site = new_site(owner: user)

        conn1 =
          put(conn, "/api/v1/sites/guests?site_id=#{site.domain}", %{
            "role" => "viewer",
            "email" => "test@example.com"
          })

        assert_email_delivered_with(to: [nil: "test@example.com"])
        assert json_response(conn1, 200)

        conn2 =
          put(conn, "/api/v1/sites/guests?site_id=#{site.domain}", %{
            "role" => "editor",
            "email" => "test@example.com"
          })

        assert %{"role" => "viewer", "status" => "invited"} = json_response(conn2, 200)

        assert %{memberships: [_], invitations: [%{role: "viewer"}]} =
                 Plausible.Sites.list_people(site)

        assert_no_emails_delivered()
      end

      test "is idempotent when membership already present", %{conn: conn, user: user} do
        site = new_site(owner: user)
        guest = new_user(email: "guest@example.com")

        add_guest(site, role: :viewer, user: guest)

        conn =
          put(conn, "/api/v1/sites/guests?site_id=#{site.domain}", %{
            "role" => "editor",
            "email" => "guest@example.com"
          })

        assert %{"role" => "viewer", "status" => "accepted"} = json_response(conn, 200)

        assert %{
                 memberships: [%{user: _}, %{user: %{email: "guest@example.com"}}],
                 invitations: []
               } =
                 Plausible.Sites.list_people(site)

        assert_no_emails_delivered()
      end

      test "fails for unknown role", %{conn: conn, user: user} do
        site = new_site(owner: user)

        conn =
          put(conn, "/api/v1/sites/guests?site_id=#{site.domain}", %{
            "role" => "owner",
            "email" => "test@example.com"
          })

        assert %{"error" => error} = json_response(conn, 400)

        assert error =~
                 "Parameter `role` is required to create guest. Possible values: `viewer` or `editor`"

        assert_no_emails_delivered()
      end
    end

    describe "DELETE /api/v1/sites/guests" do
      test "no-op when nothing to delete", %{conn: conn, user: user} do
        site = new_site(owner: user)

        conn = delete(conn, "/api/v1/sites/guests/test@example.com?site_id=#{site.domain}")

        assert json_response(conn, 200) == %{"deleted" => true}
      end

      test "deletes invitation", %{conn: conn, user: user} do
        site = new_site(owner: user)

        invite_guest(site, "invite@example.com", inviter: user, role: :viewer)

        assert %{invitations: [_]} = Plausible.Sites.list_people(site)

        conn = delete(conn, "/api/v1/sites/guests/invite@example.com?site_id=#{site.domain}")

        assert json_response(conn, 200) == %{"deleted" => true}

        assert %{invitations: []} = Plausible.Sites.list_people(site)
      end

      test "deletes guest membership", %{conn: conn, user: user} do
        site = new_site(owner: user)

        guest = new_user(email: "guest@example.com")
        add_guest(site, role: :viewer, user: guest)

        assert %{memberships: [_, _]} = Plausible.Sites.list_people(site)

        conn = delete(conn, "/api/v1/sites/guests/#{guest.email}?site_id=#{site.domain}")

        assert json_response(conn, 200) == %{"deleted" => true}

        assert %{memberships: [_]} = Plausible.Sites.list_people(site)
      end

      test "is idempotent", %{conn: conn, user: user} do
        site = new_site(owner: user)

        invite_guest(site, "third@example.com", inviter: user, role: :viewer)

        assert %{invitations: [_]} = Plausible.Sites.list_people(site)

        conn1 = delete(conn, "/api/v1/sites/guests/third@example.com?site_id=#{site.domain}")
        assert json_response(conn1, 200) == %{"deleted" => true}

        conn2 = delete(conn, "/api/v1/sites/guests/third@example.com?site_id=#{site.domain}")
        assert json_response(conn2, 200) == %{"deleted" => true}
      end

      test "won't delete non-guest membership", %{conn: conn, user: user} do
        site = new_site(owner: user)

        assert %{memberships: [_]} = Plausible.Sites.list_people(site)

        conn = delete(conn, "/api/v1/sites/guests/#{user.email}?site_id=#{site.domain}")

        assert json_response(conn, 200) == %{"deleted" => true}

        assert %{memberships: [_]} = Plausible.Sites.list_people(site)
      end
    end

    describe "GET /api/v1/sites/:site_id" do
      setup :create_site

      test "get a site by its domain", %{conn: conn, site: site} do
        site =
          site
          |> Ecto.Changeset.change(allowed_event_props: ["logged_in", "author"])
          |> Repo.update!()

        conn = get(conn, "/api/v1/sites/" <> site.domain)

        assert json_response(conn, 200) == %{
                 "domain" => site.domain,
                 "timezone" => site.timezone,
                 "custom_properties" => ["logged_in", "author"]
               }
      end

      test "get a site by old site_id after domain change", %{conn: conn, site: site} do
        old_domain = site.domain
        new_domain = "new.example.com"

        Plausible.Site.Domain.change(site, new_domain)

        conn = get(conn, "/api/v1/sites/" <> old_domain)

        assert json_response(conn, 200) == %{
                 "domain" => new_domain,
                 "timezone" => site.timezone,
                 "custom_properties" => []
               }
      end

      test "get a site for user with read-only scope", %{conn: conn, user: user, site: site} do
        api_key = insert(:api_key, user: user, scopes: ["stats:read:*"])

        conn =
          conn
          |> Plug.Conn.put_req_header("authorization", "Bearer #{api_key.key}")
          |> get("/api/v1/sites/" <> site.domain)

        assert json_response(conn, 200) == %{
                 "domain" => site.domain,
                 "timezone" => site.timezone,
                 "custom_properties" => []
               }
      end

      test "is 404 when site cannot be found", %{conn: conn} do
        conn = get(conn, "/api/v1/sites/foobar.baz")

        assert json_response(conn, 404) == %{"error" => "Site could not be found"}
      end

      test "is 404 when user is not a member of the site", %{conn: conn} do
        site = insert(:site)

        conn = get(conn, "/api/v1/sites/" <> site.domain)

        assert json_response(conn, 404) == %{"error" => "Site could not be found"}
      end
    end

    describe "GET /api/v1/goals" do
      setup :create_site

      test "returns empty when there are no goals for site", %{conn: conn, site: site} do
        conn = get(conn, "/api/v1/sites/goals?site_id=" <> site.domain)

        assert json_response(conn, 200) == %{
                 "goals" => [],
                 "meta" => %{
                   "before" => nil,
                   "after" => nil,
                   "limit" => 100
                 }
               }
      end

      test "returns goals when present", %{conn: conn, site: site} do
        goal1 = insert(:goal, %{site: site, page_path: "/login"})
        goal2 = insert(:goal, %{site: site, event_name: "Signup"})
        goal3 = insert(:goal, %{site: site, event_name: "Purchase", currency: "USD"})

        conn = get(conn, "/api/v1/sites/goals?site_id=" <> site.domain)

        assert json_response(conn, 200) == %{
                 "goals" => [
                   %{
                     "id" => goal3.id,
                     "display_name" => "Purchase",
                     "goal_type" => "event",
                     "event_name" => "Purchase",
                     "page_path" => nil
                   },
                   %{
                     "id" => goal2.id,
                     "display_name" => "Signup",
                     "goal_type" => "event",
                     "event_name" => "Signup",
                     "page_path" => nil
                   },
                   %{
                     "id" => goal1.id,
                     "display_name" => "Visit /login",
                     "goal_type" => "page",
                     "event_name" => nil,
                     "page_path" => "/login"
                   }
                 ],
                 "meta" => %{
                   "before" => nil,
                   "after" => nil,
                   "limit" => 100
                 }
               }
      end

      test "returns goals for site where user is viewer", %{site: site} do
        viewer = new_user()
        add_guest(site, user: viewer, role: :viewer)

        %{id: goal_id} = insert(:goal, %{site: site, event_name: "Signup"})

        api_key = insert(:api_key, user: viewer, scopes: ["sites:provision:*"])
        conn = Plug.Conn.put_req_header(build_conn(), "authorization", "Bearer #{api_key.key}")

        conn = get(conn, "/api/v1/sites/goals?site_id=" <> site.domain)

        assert %{"goals" => [%{"id" => ^goal_id}]} = json_response(conn, 200)
      end

      test "handles pagination correctly", %{conn: conn, site: site} do
        %{id: goal1_id} = insert(:goal, %{site: site, page_path: "/login"})
        %{id: goal2_id} = insert(:goal, %{site: site, event_name: "Signup"})
        %{id: goal3_id} = insert(:goal, %{site: site, event_name: "Purchase", currency: "USD"})

        conn1 = get(conn, "/api/v1/sites/goals?limit=2&site_id=" <> site.domain)

        assert %{
                 "goals" => [
                   %{"id" => ^goal3_id},
                   %{"id" => ^goal2_id}
                 ],
                 "meta" => %{
                   "before" => nil,
                   "after" => after_cursor,
                   "limit" => 2
                 }
               } = json_response(conn1, 200)

        conn2 =
          get(conn, "/api/v1/sites/goals?limit=2&after=#{after_cursor}&site_id=" <> site.domain)

        assert %{
                 "goals" => [
                   %{"id" => ^goal1_id}
                 ],
                 "meta" => %{
                   "before" => before_cursor,
                   "after" => nil,
                   "limit" => 2
                 }
               } = json_response(conn2, 200)

        assert is_binary(before_cursor)
      end

      test "lists goals for user with read-only scope", %{conn: conn, user: user, site: site} do
        %{id: goal_id} = insert(:goal, %{site: site, page_path: "/login"})
        api_key = insert(:api_key, user: user, scopes: ["stats:read:*"])

        conn =
          conn
          |> Plug.Conn.put_req_header("authorization", "Bearer #{api_key.key}")
          |> get("/api/v1/sites/goals?site_id=" <> site.domain)

        assert %{"goals" => [%{"id" => ^goal_id}]} = json_response(conn, 200)
      end

      test "returns error when `site_id` parameter is missing", %{conn: conn} do
        conn = get(conn, "/api/v1/sites/goals")

        assert json_response(conn, 400) == %{
                 "error" => "Parameter `site_id` is required to list goals"
               }
      end

      test "returns error when `site_id` parameter is invalid", %{conn: conn} do
        conn = get(conn, "/api/v1/sites/goals?site_id=does.not.exist")

        assert json_response(conn, 404) == %{
                 "error" => "Site could not be found"
               }
      end

      test "returns error when user is not a member of the site", %{conn: conn} do
        site = insert(:site)

        conn = get(conn, "/api/v1/sites/goals?site_id=" <> site.domain)

        assert json_response(conn, 404) == %{
                 "error" => "Site could not be found"
               }
      end
    end

    describe "PUT /api/v1/sites/:site_id" do
      setup :create_site

      test "can change domain name", %{conn: conn, site: site} do
        old_domain = site.domain
        assert old_domain != "new.example.com"

        conn =
          put(conn, "/api/v1/sites/#{old_domain}", %{
            "domain" => "new.example.com"
          })

        assert json_response(conn, 200) == %{
                 "domain" => "new.example.com",
                 "timezone" => "UTC"
               }

        site = Repo.reload!(site)

        assert site.domain == "new.example.com"
        assert site.domain_changed_from == old_domain
      end

      test "can't make a no-op change", %{conn: conn, site: site} do
        conn =
          put(conn, "/api/v1/sites/#{site.domain}", %{
            "domain" => site.domain
          })

        assert json_response(conn, 400) == %{
                 "error" => "domain: New domain must be different than the current one"
               }
      end

      test "domain parameter is required", %{conn: conn, site: site} do
        conn = put(conn, "/api/v1/sites/#{site.domain}", %{})

        assert json_response(conn, 400) == %{
                 "error" => "domain: can't be blank"
               }
      end
    end
  end
end
