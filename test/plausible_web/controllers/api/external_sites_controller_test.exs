defmodule PlausibleWeb.Api.ExternalSitesControllerTest do
  @moduledoc """
  Tests for the following endpoints

  GET /api/v1/sites/teams

  GET /api/v1/sites/guests
  PUT /api/v1/sites/guests
  DELETE /api/v1/sites/guests

  PUT /api/v1/sites/shared-links

  GET /api/v1/custom-props
  PUT /api/v1/sites/custom-props
  DELETE /api/v1/sites/custom-props/:property

  GET /api/v1/goals
  PUT /api/v1/sites/goals
  DELETE /api/v1/sites/goals/:goal_id

  Site CRUD endpoints tests are in ExternalSitesControllerSitesCrudApiTest
  """
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

      test "shows only one team for team scoped key", %{conn: conn, user: user} do
        user |> subscribe_to_business_plan()

        personal_team = team_of(user)

        another_team = new_site().team |> Plausible.Teams.complete_setup()
        add_member(another_team, user: user, role: :admin)

        api_key = insert(:api_key, user: user, team: personal_team, scopes: ["sites:provision:*"])
        conn = Plug.Conn.put_req_header(conn, "authorization", "Bearer #{api_key.key}")

        conn = get(conn, "/api/v1/sites/teams")

        assert json_response(conn, 200) == %{
                 "teams" => [
                   %{
                     "id" => personal_team.identifier,
                     "name" => "My Personal Sites",
                     "api_available" => true
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

    describe "PUT /api/v1/sites/shared-links" do
      setup :create_site

      setup %{user: user} do
        subscribe_to_enterprise_plan(user,
          features: [
            Plausible.Billing.Feature.SharedLinks,
            Plausible.Billing.Feature.StatsAPI,
            Plausible.Billing.Feature.SitesAPI
          ]
        )

        :ok
      end

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

      test "fails when team does not match team-scoped key", %{conn: conn, user: user, site: site} do
        another_team = new_user() |> subscribe_to_business_plan() |> team_of()
        add_member(another_team, user: user, role: :admin)
        api_key = insert(:api_key, user: user, team: another_team, scopes: ["sites:provision:*"])
        conn = Plug.Conn.put_req_header(conn, "authorization", "Bearer #{api_key.key}")

        conn =
          put(conn, "/api/v1/sites/shared-links", %{
            site_id: site.domain,
            name: "WordPress"
          })

        res = json_response(conn, 401)
        assert res["error"] =~ "Invalid API key"
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

      @tag :capture_log
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

        res = json_response(conn, 402)
        assert res["error"] =~ "API key does not have access to Sites API"
      end

      test "fails to create without access to SharedLinks feature", %{
        conn: conn,
        site: site,
        user: user
      } do
        subscribe_to_enterprise_plan(user, features: [Plausible.Billing.Feature.SitesAPI])

        conn =
          put(conn, "/api/v1/sites/shared-links", %{
            site_id: site.domain,
            name: "My Link"
          })

        res = json_response(conn, 402)

        assert res["error"] == "Your current subscription plan does not include Shared Links"
      end

      for special_name <- Plausible.Sites.shared_link_special_names() do
        test "fails to create with the special '#{special_name}' name intended for Plugins API",
             %{conn: conn, site: site} do
          conn =
            put(conn, "/api/v1/sites/shared-links", %{
              site_id: site.domain,
              name: unquote(special_name)
            })

          res = json_response(conn, 400)

          assert res["error"] == "This name is reserved. Please choose another one"
        end
      end
    end

    describe "PUT /api/v1/sites/custom-props" do
      setup :create_site

      setup %{user: user} do
        subscribe_to_enterprise_plan(user,
          features: [
            Plausible.Billing.Feature.Props,
            Plausible.Billing.Feature.StatsAPI,
            Plausible.Billing.Feature.SitesAPI
          ]
        )

        :ok
      end

      test "can add a custom property to a site", %{conn: conn, site: site} do
        conn =
          put(conn, "/api/v1/sites/custom-props", %{
            site_id: site.domain,
            property: "prop1"
          })

        res = json_response(conn, 200)

        assert res["created"] == true

        assert Repo.reload!(site).allowed_event_props == ["prop1"]
      end

      test "can add a custom prop using old site_id after domain change", %{
        conn: conn,
        site: site
      } do
        old_domain = site.domain
        new_domain = "new.example.com"

        Plausible.Site.Domain.change(site, new_domain)

        conn =
          put(conn, "/api/v1/sites/custom-props", %{
            site_id: old_domain,
            property: "prop1"
          })

        res = json_response(conn, 200)

        assert res["created"] == true

        assert Repo.reload!(site).allowed_event_props == ["prop1"]
      end

      test "is idempotent", %{conn: conn, site: site} do
        conn =
          put(conn, "/api/v1/sites/custom-props", %{
            site_id: site.domain,
            property: "prop1"
          })

        assert %{"created" => true} = json_response(conn, 200)

        conn =
          put(conn, "/api/v1/sites/custom-props", %{
            site_id: site.domain,
            property: "prop1"
          })

        assert %{"created" => true} = json_response(conn, 200)

        assert Repo.reload!(site).allowed_event_props == ["prop1"]
      end

      test "fails to add a custom prop with too long name", %{conn: conn, site: site} do
        conn =
          put(conn, "/api/v1/sites/custom-props", %{
            site_id: site.domain,
            property: String.duplicate("a", Plausible.Props.max_prop_key_length() + 1)
          })

        assert %{"error" => "Parameter `property` is too long"} = json_response(conn, 400)
      end

      test "fails to add a custom prop when props list is too long", %{conn: conn, site: site} do
        max_props = Plausible.Props.max_props()

        Enum.reduce(1..max_props, site, fn idx, site ->
          {:ok, site} = Plausible.Props.allow(site, "prop#{idx}")
          site
        end)

        conn =
          put(conn, "/api/v1/sites/custom-props", %{
            site_id: site.domain,
            property: "prop#{max_props + 1}"
          })

        assert %{"error" => "Can't add any more custom properties"} = json_response(conn, 400)
      end

      test "fails when team does not match team-scoped key", %{conn: conn, user: user, site: site} do
        another_team = new_user() |> subscribe_to_business_plan() |> team_of()
        add_member(another_team, user: user, role: :admin)
        api_key = insert(:api_key, user: user, team: another_team, scopes: ["sites:provision:*"])
        conn = Plug.Conn.put_req_header(conn, "authorization", "Bearer #{api_key.key}")

        conn =
          put(conn, "/api/v1/sites/custom-props", %{
            site_id: site.domain,
            property: "prop1"
          })

        res = json_response(conn, 401)
        assert res["error"] =~ "Invalid API key"
      end

      test "returns 400 when site id missing", %{conn: conn} do
        conn =
          put(conn, "/api/v1/sites/custom-props", %{
            property: "prop1"
          })

        res = json_response(conn, 400)
        assert res["error"] == "Parameter `site_id` is required to create a custom property"
      end

      test "returns 404 when site id is non existent", %{conn: conn} do
        conn =
          put(conn, "/api/v1/sites/custom-props", %{
            property: "prop1",
            site_id: "bad"
          })

        res = json_response(conn, 404)
        assert res["error"] == "Site could not be found"
      end

      @tag :capture_log
      test "returns 404 when api key owner does not have permissions to create a goal", %{
        conn: conn,
        user: user
      } do
        site = new_site()

        add_guest(site, user: user, role: :viewer)

        conn =
          put(conn, "/api/v1/sites/custom-props", %{
            site_id: site.domain,
            property: "prop1"
          })

        res = json_response(conn, 402)
        assert res["error"] =~ "API key does not have access to Sites API"
      end

      test "returns 400 when property missing", %{conn: conn, site: site} do
        conn =
          put(conn, "/api/v1/sites/custom-props", %{
            site_id: site.domain
          })

        res = json_response(conn, 400)
        assert res["error"] == "Parameter `property` is required to create a custom property"
      end
    end

    describe "PUT /api/v1/sites/goals" do
      setup :create_site

      setup %{user: user} do
        subscribe_to_enterprise_plan(user,
          features: [Plausible.Billing.Feature.StatsAPI, Plausible.Billing.Feature.SitesAPI]
        )

        :ok
      end

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

      test "fails when team does not match team-scoped key", %{conn: conn, user: user, site: site} do
        another_team = new_user() |> subscribe_to_business_plan() |> team_of()
        add_member(another_team, user: user, role: :admin)
        api_key = insert(:api_key, user: user, team: another_team, scopes: ["sites:provision:*"])
        conn = Plug.Conn.put_req_header(conn, "authorization", "Bearer #{api_key.key}")

        conn =
          put(conn, "/api/v1/sites/goals", %{
            site_id: site.domain,
            goal_type: "event",
            event_name: "Signup"
          })

        res = json_response(conn, 401)
        assert res["error"] =~ "Invalid API key"
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

      @tag :capture_log
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

        res = json_response(conn, 402)
        assert res["error"] =~ "API key does not have access to Sites API"
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

    describe "DELETE /api/v1/sites/custom-props/:property" do
      setup :create_site

      setup %{user: user} do
        subscribe_to_enterprise_plan(user,
          features: [
            Plausible.Billing.Feature.Props,
            Plausible.Billing.Feature.StatsAPI,
            Plausible.Billing.Feature.SitesAPI
          ]
        )

        :ok
      end

      test "deletes a custom property", %{conn: conn, site: site} do
        conn =
          put(conn, "/api/v1/sites/custom-props", %{
            site_id: site.domain,
            property: "prop1"
          })

        assert %{"created" => true} = json_response(conn, 200)

        conn =
          delete(conn, "/api/v1/sites/custom-props/prop1", %{
            site_id: site.domain
          })

        assert json_response(conn, 200) == %{"deleted" => true}

        assert Repo.reload!(site).allowed_event_props == []
      end

      test "deletes a custom property with slash in name", %{conn: conn, site: site} do
        conn =
          put(conn, "/api/v1/sites/custom-props", %{
            site_id: site.domain,
            property: "prop1/key/with/slashes"
          })

        assert %{"created" => true} = json_response(conn, 200)

        conn =
          delete(conn, "/api/v1/sites/custom-props/prop1/key/with/slashes", %{
            site_id: site.domain
          })

        assert json_response(conn, 200) == %{"deleted" => true}

        assert Repo.reload!(site).allowed_event_props == []
      end

      test "deletes a custom prop using old site_id after domain change", %{
        conn: conn,
        site: site
      } do
        old_domain = site.domain
        new_domain = "new.example.com"

        Plausible.Site.Domain.change(site, new_domain)

        conn =
          put(conn, "/api/v1/sites/custom-props", %{
            site_id: new_domain,
            property: "prop1"
          })

        assert %{"created" => true} = json_response(conn, 200)

        conn =
          delete(conn, "/api/v1/sites/custom-props/prop1", %{
            site_id: old_domain
          })

        assert json_response(conn, 200) == %{"deleted" => true}
        assert Repo.reload!(site).allowed_event_props == []
      end

      test "fails when team does not match team-scoped key", %{conn: conn, user: user, site: site} do
        conn1 =
          put(conn, "/api/v1/sites/custom-props", %{
            site_id: site.domain,
            property: "prop1"
          })

        assert %{"created" => true} = json_response(conn1, 200)

        another_team = new_user() |> subscribe_to_business_plan() |> team_of()
        add_member(another_team, user: user, role: :admin)
        api_key = insert(:api_key, user: user, team: another_team, scopes: ["sites:provision:*"])
        conn = Plug.Conn.put_req_header(conn, "authorization", "Bearer #{api_key.key}")

        conn =
          delete(conn, "/api/v1/sites/custom-props/prop1", %{
            site_id: site.domain
          })

        res = json_response(conn, 401)
        assert res["error"] =~ "Invalid API key"
      end

      test "handles non-existent custom prop gracefully", %{conn: conn, site: site} do
        conn =
          delete(conn, "/api/v1/sites/custom-props/none", %{
            site_id: site.domain
          })

        assert json_response(conn, 200) == %{"deleted" => true}
      end

      @tag :capture_log
      test "cannot delete a custom prop belongs to a site that the user does not own", %{
        conn: conn,
        user: user
      } do
        site = new_site()
        add_guest(site, user: user, role: :viewer)

        conn =
          delete(conn, "/api/v1/sites/custom-props/prop1", %{
            site_id: site.domain
          })

        assert %{"error" => error} = json_response(conn, 402)
        assert error =~ "API key does not have access to Sites API"
      end

      test "cannot access with a bad API key scope", %{conn: conn, site: site, user: user} do
        {:ok, site} = Plausible.Props.allow(site, "prop1")
        api_key = insert(:api_key, user: user, scopes: ["stats:read:*"])

        conn =
          conn
          |> Plug.Conn.put_req_header("authorization", "Bearer #{api_key.key}")

        conn =
          delete(conn, "/api/v1/sites/custom-props/prop1", %{
            site_id: site.domain
          })

        assert json_response(conn, 401) == %{
                 "error" =>
                   "Invalid API key. Please make sure you're using a valid API key with access to the resource you've requested."
               }
      end
    end

    describe "DELETE /api/v1/sites/goals/:goal_id" do
      setup :create_site

      setup %{user: user} do
        subscribe_to_enterprise_plan(user,
          features: [
            Plausible.Billing.Feature.StatsAPI,
            Plausible.Billing.Feature.SitesAPI
          ]
        )

        :ok
      end

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

      test "fails when team does not match team-scoped key", %{conn: conn, user: user, site: site} do
        conn1 =
          put(conn, "/api/v1/sites/goals", %{
            site_id: site.domain,
            goal_type: "event",
            event_name: "Signup"
          })

        %{"id" => goal_id} = json_response(conn1, 200)

        another_team = new_user() |> subscribe_to_business_plan() |> team_of()
        add_member(another_team, user: user, role: :admin)
        api_key = insert(:api_key, user: user, team: another_team, scopes: ["sites:provision:*"])
        conn = Plug.Conn.put_req_header(conn, "authorization", "Bearer #{api_key.key}")

        conn =
          delete(conn, "/api/v1/sites/goals/#{goal_id}", %{
            site_id: site.domain
          })

        res = json_response(conn, 401)
        assert res["error"] =~ "Invalid API key"
      end

      test "is 404 when goal cannot be found", %{conn: conn, site: site} do
        conn =
          delete(conn, "/api/v1/sites/goals/0", %{
            site_id: site.domain
          })

        assert json_response(conn, 404) == %{"error" => "Goal could not be found"}
      end

      @tag :capture_log
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

        assert %{"error" => error} = json_response(conn, 402)
        assert error =~ "API key does not have access to Sites API"
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

      test "fails when team does not match team-scoped key", %{conn: conn, user: user} do
        another_team = new_user() |> subscribe_to_business_plan() |> team_of()
        add_member(another_team, user: user, role: :admin)
        api_key = insert(:api_key, user: user, team: another_team, scopes: ["sites:provision:*"])
        conn = Plug.Conn.put_req_header(conn, "authorization", "Bearer #{api_key.key}")

        site = new_site(owner: user)

        _guest = add_guest(site, site: site, role: :editor)

        conn = get(conn, "/api/v1/sites/guests?site_id=#{site.domain}")

        res = json_response(conn, 401)
        assert res["error"] =~ "Invalid API key"
      end
    end

    describe "PUT /api/v1/sites/guests" do
      setup %{user: user} do
        subscribe_to_enterprise_plan(user,
          features: [
            Plausible.Billing.Feature.StatsAPI,
            Plausible.Billing.Feature.SitesAPI
          ]
        )

        :ok
      end

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

        assert %{memberships: [_], invitations: [%{role: :viewer}]} =
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

      test "fails when team does not match team-scoped key", %{conn: conn, user: user} do
        site = new_site(owner: user)

        another_team = new_user() |> subscribe_to_business_plan() |> team_of()
        add_member(another_team, user: user, role: :admin)
        api_key = insert(:api_key, user: user, team: another_team, scopes: ["sites:provision:*"])
        conn = Plug.Conn.put_req_header(conn, "authorization", "Bearer #{api_key.key}")

        conn =
          put(conn, "/api/v1/sites/guests?site_id=#{site.domain}", %{
            "role" => "viewer",
            "email" => "test@example.com"
          })

        res = json_response(conn, 401)
        assert res["error"] =~ "Invalid API key"
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
      setup %{user: user} do
        subscribe_to_enterprise_plan(user,
          features: [Plausible.Billing.Feature.StatsAPI, Plausible.Billing.Feature.SitesAPI]
        )

        :ok
      end

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

      test "fails when team does not match team-scoped key", %{conn: conn, user: user} do
        site = new_site(owner: user)

        another_team = new_user() |> subscribe_to_business_plan() |> team_of()
        add_member(another_team, user: user, role: :admin)
        api_key = insert(:api_key, user: user, team: another_team, scopes: ["sites:provision:*"])
        conn = Plug.Conn.put_req_header(conn, "authorization", "Bearer #{api_key.key}")

        conn = delete(conn, "/api/v1/sites/guests/test@example.com?site_id=#{site.domain}")

        res = json_response(conn, 401)
        assert res["error"] =~ "Invalid API key"
      end

      test "won't delete non-guest membership", %{conn: conn, user: user} do
        site = new_site(owner: user)

        assert %{memberships: [_]} = Plausible.Sites.list_people(site)

        conn = delete(conn, "/api/v1/sites/guests/#{user.email}?site_id=#{site.domain}")

        assert json_response(conn, 200) == %{"deleted" => true}

        assert %{memberships: [_]} = Plausible.Sites.list_people(site)
      end
    end

    describe "GET /api/v1/custom-props" do
      setup :create_site

      test "returns empty when there are no custom props for site", %{conn: conn, site: site} do
        conn = get(conn, "/api/v1/sites/custom-props?site_id=" <> site.domain)

        assert json_response(conn, 200) == %{"custom_properties" => []}
      end

      test "returns custom props when present", %{conn: conn, site: site} do
        {:ok, site} = Plausible.Props.allow(site, "prop1")
        {:ok, site} = Plausible.Props.allow(site, "prop2")
        Plausible.Props.allow(site, "prop3")

        conn = get(conn, "/api/v1/sites/custom-props?site_id=" <> site.domain)

        assert json_response(conn, 200) == %{
                 "custom_properties" => [
                   %{"property" => "prop1"},
                   %{"property" => "prop2"},
                   %{"property" => "prop3"}
                 ]
               }
      end

      @tag :capture_log
      test "returns custom props for site where user is viewer", %{site: site} do
        viewer = new_user()
        add_guest(site, user: viewer, role: :viewer)

        {:ok, site} = Plausible.Props.allow(site, "prop1")

        api_key = insert(:api_key, user: viewer, scopes: ["sites:provision:*"])
        conn = Plug.Conn.put_req_header(build_conn(), "authorization", "Bearer #{api_key.key}")

        conn = get(conn, "/api/v1/sites/custom-props?site_id=" <> site.domain)

        assert %{"custom_properties" => [%{"property" => "prop1"}]} = json_response(conn, 200)
      end

      test "lists custom props for user with read-only scope", %{
        conn: conn,
        user: user,
        site: site
      } do
        {:ok, site} = Plausible.Props.allow(site, "prop1")
        api_key = insert(:api_key, user: user, scopes: ["stats:read:*"])

        conn =
          conn
          |> Plug.Conn.put_req_header("authorization", "Bearer #{api_key.key}")
          |> get("/api/v1/sites/custom-props?site_id=" <> site.domain)

        assert %{"custom_properties" => [%{"property" => "prop1"}]} = json_response(conn, 200)
      end

      test "fails when team does not match team-scoped key", %{conn: conn, user: user, site: site} do
        another_team = new_user() |> subscribe_to_business_plan() |> team_of()
        add_member(another_team, user: user, role: :admin)
        api_key = insert(:api_key, user: user, team: another_team, scopes: ["sites:provision:*"])
        conn = Plug.Conn.put_req_header(conn, "authorization", "Bearer #{api_key.key}")

        _goal = insert(:goal, %{site: site, page_path: "/login"})

        conn = get(conn, "/api/v1/sites/custom-props?site_id=" <> site.domain)

        res = json_response(conn, 401)
        assert res["error"] =~ "Invalid API key"
      end

      test "returns error when `site_id` parameter is missing", %{conn: conn} do
        conn = get(conn, "/api/v1/sites/custom-props")

        assert json_response(conn, 400) == %{
                 "error" => "Parameter `site_id` is required to list custom properties"
               }
      end

      test "returns error when `site_id` parameter is invalid", %{conn: conn} do
        conn = get(conn, "/api/v1/sites/custom-props?site_id=does.not.exist")

        assert json_response(conn, 404) == %{
                 "error" => "Site could not be found"
               }
      end

      @tag :capture_log
      test "returns error when user is not a member of the site", %{conn: conn} do
        site = new_site()

        conn = get(conn, "/api/v1/sites/custom-props?site_id=" <> site.domain)

        assert %{"error" => error} = json_response(conn, 401)
        assert(error =~ "Invalid API key")
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

      @tag :capture_log
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

      test "fails when team does not match team-scoped key", %{conn: conn, user: user, site: site} do
        another_team = new_user() |> subscribe_to_business_plan() |> team_of()
        add_member(another_team, user: user, role: :admin)
        api_key = insert(:api_key, user: user, team: another_team, scopes: ["sites:provision:*"])
        conn = Plug.Conn.put_req_header(conn, "authorization", "Bearer #{api_key.key}")

        _goal = insert(:goal, %{site: site, page_path: "/login"})

        conn = get(conn, "/api/v1/sites/goals?site_id=" <> site.domain)

        res = json_response(conn, 401)
        assert res["error"] =~ "Invalid API key"
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

      @tag :capture_log
      test "returns error when user is not a member of the site", %{conn: conn} do
        site = new_site()

        conn = get(conn, "/api/v1/sites/goals?site_id=" <> site.domain)

        assert %{"error" => error} = json_response(conn, 401)
        assert error =~ "Invalid API key"
      end
    end
  end
end
