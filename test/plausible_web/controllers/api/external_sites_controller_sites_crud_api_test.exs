defmodule PlausibleWeb.Api.ExternalSitesControllerSitesCrudApiTest do
  @moduledoc """
  Tests for Sites create/read/update/delete API with `scriptv2` feature flag enabled.
  It has overlap with some of the tests in `PlausibleWeb.Api.ExternalSitesControllerTest` test suite.
  The overlapped tests from that suite can be deleted once the feature flag is enabled globally.
  """
  use Plausible
  use PlausibleWeb.ConnCase, async: false
  use Plausible.Repo
  use Plausible.Teams.Test
  use Bamboo.Test

  on_ee do
    setup :create_user

    setup %{conn: conn, user: user} do
      FunWithFlags.enable(:scriptv2, for_actor: user)
      api_key = insert(:api_key, user: user, scopes: ["sites:provision:*"])
      conn = Plug.Conn.put_req_header(conn, "authorization", "Bearer #{api_key.key}")
      {:ok, api_key: api_key, conn: conn}
    end

    describe "POST /api/v1/sites" do
      test "can create a site", %{conn: conn} do
        conn =
          post(conn, "/api/v1/sites", %{
            "domain" => "some-site.domain",
            "timezone" => "Europe/Tallinn"
          })

        response = json_response(conn, 200)

        assert_matches ^strict_map(%{
                         "domain" => "some-site.domain",
                         "timezone" => "Europe/Tallinn",
                         "custom_properties" => [],
                         "tracker_script_configuration" =>
                           ^strict_map(%{
                             "id" => ^any(:string),
                             "installation_type" => nil,
                             "track_404_pages" => false,
                             "hash_based_routing" => false,
                             "outbound_links" => false,
                             "file_downloads" => false,
                             "revenue_tracking" => false,
                             "tagged_events" => false,
                             "form_submissions" => false,
                             "pageview_props" => false
                           })
                       }) = response
      end

      test "can create a site with a specific tracker script configuration", %{conn: conn} do
        payload = %{
          "domain" => "some-site.domain",
          "timezone" => "Europe/Tallinn",
          "tracker_script_configuration" => %{
            "installation_type" => "wordpress",
            "track_404_pages" => false,
            "hash_based_routing" => false,
            "outbound_links" => false,
            "file_downloads" => true,
            "revenue_tracking" => false,
            "tagged_events" => false,
            "form_submissions" => true,
            "pageview_props" => false
          }
        }

        conn =
          post(conn, "/api/v1/sites", payload)

        response = json_response(conn, 200)

        assert_matches ^strict_map(%{
                         "domain" => ^payload["domain"],
                         "timezone" => ^payload["timezone"],
                         "custom_properties" => [],
                         "tracker_script_configuration" =>
                           ^strict_map(%{
                             "id" => ^any(:string),
                             "installation_type" =>
                               ^payload["tracker_script_configuration"]["installation_type"],
                             "track_404_pages" =>
                               ^payload["tracker_script_configuration"]["track_404_pages"],
                             "hash_based_routing" =>
                               ^payload["tracker_script_configuration"]["hash_based_routing"],
                             "outbound_links" =>
                               ^payload["tracker_script_configuration"]["outbound_links"],
                             "file_downloads" =>
                               ^payload["tracker_script_configuration"]["file_downloads"],
                             "revenue_tracking" =>
                               ^payload["tracker_script_configuration"]["revenue_tracking"],
                             "tagged_events" =>
                               ^payload["tracker_script_configuration"]["tagged_events"],
                             "form_submissions" =>
                               ^payload["tracker_script_configuration"]["form_submissions"],
                             "pageview_props" =>
                               ^payload["tracker_script_configuration"]["pageview_props"]
                           })
                       }) = response
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

        response = json_response(conn, 200)

        assert_matches ^strict_map(%{
                         "domain" => "some-site.domain",
                         "timezone" => "Europe/Tallinn",
                         "custom_properties" => [],
                         "tracker_script_configuration" =>
                           ^strict_map(%{
                             "id" => ^any(:string),
                             "installation_type" => nil,
                             "track_404_pages" => false,
                             "hash_based_routing" => false,
                             "outbound_links" => false,
                             "file_downloads" => false,
                             "revenue_tracking" => false,
                             "tagged_events" => false,
                             "form_submissions" => false,
                             "pageview_props" => false
                           })
                       }) = response

        assert Repo.get_by(Plausible.Site, domain: "some-site.domain").team_id == team.id
      end

      test "creates under a particular team when team-scoped key used", %{conn: conn, user: user} do
        personal_team = user |> subscribe_to_business_plan() |> team_of()

        another_team = new_user() |> subscribe_to_business_plan() |> team_of()
        add_member(another_team, user: user, role: :admin)

        api_key = insert(:api_key, user: user, team: another_team, scopes: ["sites:provision:*"])
        conn = Plug.Conn.put_req_header(conn, "authorization", "Bearer #{api_key.key}")

        conn =
          post(conn, "/api/v1/sites", %{
            # is ignored
            "team_id" => personal_team.identifier,
            "domain" => "some-site.domain",
            "timezone" => "Europe/Tallinn"
          })

        response = json_response(conn, 200)

        assert_matches ^strict_map(%{
                         "domain" => "some-site.domain",
                         "timezone" => "Europe/Tallinn",
                         "custom_properties" => [],
                         "tracker_script_configuration" =>
                           ^strict_map(%{
                             "id" => ^any(:string),
                             "installation_type" => nil,
                             "track_404_pages" => false,
                             "hash_based_routing" => false,
                             "outbound_links" => false,
                             "file_downloads" => false,
                             "revenue_tracking" => false,
                             "tagged_events" => false,
                             "form_submissions" => false,
                             "pageview_props" => false
                           })
                       }) = response

        assert Repo.get_by(Plausible.Site, domain: "some-site.domain").team_id == another_team.id
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

        response = json_response(conn, 200)

        assert_matches ^strict_map(%{
                         "domain" => "some-site.domain",
                         "timezone" => "Etc/UTC",
                         "custom_properties" => [],
                         "tracker_script_configuration" => %{}
                       }) = response
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

      test "validates tracker script configuration if it's not nil, serializing the first error",
           %{conn: conn} do
        conn =
          post(conn, "/api/v1/sites", %{
            "domain" => "some-site.domain",
            "timezone" => "Europe/Tallinn",
            "tracker_script_configuration" => %{
              "installation_type" => "an invalid value",
              "track_404_pages" => "an invalid value"
            }
          })

        assert json_response(conn, 400) == %{
                 "error" => "tracker_script_configuration.installation_type: is invalid"
               }

        conn2 =
          post(conn, "/api/v1/sites", %{
            "domain" => "some-site.domain",
            "timezone" => "Europe/Tallinn",
            "tracker_script_configuration" => %{
              "installation_type" => "wordpress",
              "track_404_pages" => "an invalid value"
            }
          })

        assert json_response(conn2, 400) == %{
                 "error" => "tracker_script_configuration.track_404_pages: is invalid"
               }
      end

      test "creating the site and creating the tracker script configuration are run as a transaction: if creating the tracker script configuration fails, the site is not inserted",
           %{conn: conn} do
        conn =
          post(conn, "/api/v1/sites", %{
            "domain" => "some-site.domain",
            "timezone" => "Europe/Tallinn",
            "tracker_script_configuration" => %{
              "installation_type" => "an invalid value"
            }
          })

        assert json_response(conn, 400) == %{
                 "error" => "tracker_script_configuration.installation_type: is invalid"
               }

        assert Repo.get_by(Plausible.Site, domain: "some-site.domain") == nil

        # try again with a valid tracker script configuration
        conn2 =
          post(conn, "/api/v1/sites", %{
            "domain" => "some-site.domain",
            "timezone" => "Europe/Tallinn",
            "tracker_script_configuration" => %{
              "installation_type" => "manual"
            }
          })

        response = json_response(conn2, 200)

        assert_matches ^strict_map(%{
                         "domain" => "some-site.domain",
                         "timezone" => "Europe/Tallinn",
                         "custom_properties" => [],
                         "tracker_script_configuration" =>
                           ^strict_map(%{
                             "id" => ^any(:string),
                             "installation_type" => "manual",
                             "track_404_pages" => false,
                             "hash_based_routing" => false,
                             "outbound_links" => false,
                             "file_downloads" => false,
                             "revenue_tracking" => false,
                             "tagged_events" => false,
                             "form_submissions" => false,
                             "pageview_props" => false
                           })
                       }) = response
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

      @tag :capture_log
      test "cannot delete a site that the user does not own", %{conn: conn, user: user} do
        site = new_site()
        add_guest(site, user: user, role: :editor)
        conn = delete(conn, "/api/v1/sites/" <> site.domain)

        assert json_response(conn, 404) == %{"error" => "Site could not be found"}
      end

      test "cannot delete if team not matching team-scoped API key", %{
        conn: conn,
        user: user,
        site: site
      } do
        another_team = new_user() |> subscribe_to_business_plan() |> team_of()
        add_member(another_team, user: user, role: :admin)
        api_key = insert(:api_key, user: user, team: another_team, scopes: ["sites:provision:*"])
        conn = Plug.Conn.put_req_header(conn, "authorization", "Bearer #{api_key.key}")

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

      test "implicitly scopes to a team for a team-scoped key", %{
        conn: conn,
        user: user
      } do
        another_team = new_user() |> subscribe_to_business_plan() |> team_of()
        add_member(another_team, user: user, role: :admin)
        site = new_site(team: another_team)
        api_key = insert(:api_key, user: user, team: another_team, scopes: ["sites:provision:*"])
        conn = Plug.Conn.put_req_header(conn, "authorization", "Bearer #{api_key.key}")

        _owned_site = new_site(owner: user)
        other_site = new_site()
        add_guest(other_site, user: user, role: :viewer)
        other_team_site = new_site()
        add_member(other_team_site.team, user: user, role: :viewer)

        # `team_id` paramaeter is ignored
        conn = get(conn, "/api/v1/sites?team_id=" <> other_team_site.team.identifier)

        assert_matches %{
                         "sites" => [
                           %{"domain" => ^site.domain}
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

    describe "GET /api/v1/sites/:site_id" do
      setup :create_site

      test "get a site by its domain", %{conn: conn, site: site} do
        site =
          site
          |> Ecto.Changeset.change(allowed_event_props: ["logged_in", "author"])
          |> Repo.update!()

        conn = get(conn, "/api/v1/sites/" <> site.domain)

        response = json_response(conn, 200)

        assert_matches ^strict_map(%{
                         "domain" => ^site.domain,
                         "timezone" => ^site.timezone,
                         "custom_properties" => ["logged_in", "author"],
                         "tracker_script_configuration" =>
                           ^strict_map(%{
                             "id" => ^any(:string),
                             "installation_type" => nil,
                             "track_404_pages" => false,
                             "hash_based_routing" => false,
                             "outbound_links" => false,
                             "file_downloads" => false,
                             "revenue_tracking" => false,
                             "tagged_events" => false,
                             "form_submissions" => false,
                             "pageview_props" => false
                           })
                       }) = response
      end

      test "get a site by old site_id after domain change", %{conn: conn, site: site} do
        old_domain = site.domain
        new_domain = "new.example.com"

        Plausible.Site.Domain.change(site, new_domain)

        conn = get(conn, "/api/v1/sites/" <> old_domain)

        response = json_response(conn, 200)

        assert_matches ^strict_map(%{
                         "domain" => ^new_domain,
                         "timezone" => ^site.timezone,
                         "custom_properties" => [],
                         "tracker_script_configuration" =>
                           ^strict_map(%{
                             "id" => ^any(:string),
                             "installation_type" => nil,
                             "track_404_pages" => false,
                             "hash_based_routing" => false,
                             "outbound_links" => false,
                             "file_downloads" => false,
                             "revenue_tracking" => false,
                             "tagged_events" => false,
                             "form_submissions" => false,
                             "pageview_props" => false
                           })
                       }) = response
      end

      test "get a site for user with read-only scope", %{conn: conn, user: user, site: site} do
        api_key = insert(:api_key, user: user, scopes: ["stats:read:*"])

        conn =
          conn
          |> Plug.Conn.put_req_header("authorization", "Bearer #{api_key.key}")
          |> get("/api/v1/sites/" <> site.domain)

        response = json_response(conn, 200)

        assert_matches ^strict_map(%{
                         "domain" => ^site.domain,
                         "timezone" => ^site.timezone,
                         "custom_properties" => [],
                         "tracker_script_configuration" =>
                           ^strict_map(%{
                             "id" => ^any(:string),
                             "installation_type" => nil,
                             "track_404_pages" => false,
                             "hash_based_routing" => false,
                             "outbound_links" => false,
                             "file_downloads" => false,
                             "revenue_tracking" => false,
                             "tagged_events" => false,
                             "form_submissions" => false,
                             "pageview_props" => false
                           })
                       }) = response
      end

      test "fails when team does not match team-scoped key", %{conn: conn, user: user, site: site} do
        another_team = new_user() |> subscribe_to_business_plan() |> team_of()
        add_member(another_team, user: user, role: :admin)
        api_key = insert(:api_key, user: user, team: another_team, scopes: ["sites:provision:*"])
        conn = Plug.Conn.put_req_header(conn, "authorization", "Bearer #{api_key.key}")

        conn = get(conn, "/api/v1/sites/" <> site.domain)

        res = json_response(conn, 404)
        assert res["error"] == "Site could not be found"
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

    describe "PUT /api/v1/sites/:site_id" do
      setup :create_site

      test "can change domain name", %{conn: conn, site: site} do
        old_domain = site.domain
        assert old_domain != "new.example.com"

        conn =
          put(conn, "/api/v1/sites/#{old_domain}", %{
            "domain" => "new.example.com"
          })

        response = json_response(conn, 200)

        assert_matches ^strict_map(%{
                         "domain" => "new.example.com",
                         "timezone" => "UTC",
                         "custom_properties" => [],
                         "tracker_script_configuration" =>
                           ^strict_map(%{
                             "id" => ^any(:string),
                             "installation_type" => nil,
                             "track_404_pages" => false,
                             "hash_based_routing" => false,
                             "outbound_links" => false,
                             "file_downloads" => false,
                             "revenue_tracking" => false,
                             "tagged_events" => false,
                             "form_submissions" => false,
                             "pageview_props" => false
                           })
                       }) = response

        site = Repo.reload!(site)

        assert site.domain == "new.example.com"
        assert site.domain_changed_from == old_domain
      end

      test "can change tracker script configuration (merging updated keys with previous configuration)",
           %{conn: conn, site: site} do
        conn =
          put(conn, "/api/v1/sites/#{site.domain}", %{
            "tracker_script_configuration" => %{
              "form_submissions" => true
            }
          })

        response = json_response(conn, 200)

        assert_matches ^strict_map(%{
                         "domain" => ^site.domain,
                         "timezone" => "UTC",
                         "custom_properties" => [],
                         "tracker_script_configuration" =>
                           ^strict_map(%{
                             "id" => ^any(:string),
                             "installation_type" => nil,
                             "track_404_pages" => false,
                             "hash_based_routing" => false,
                             "outbound_links" => false,
                             "file_downloads" => false,
                             "revenue_tracking" => false,
                             "tagged_events" => false,
                             "form_submissions" => true,
                             "pageview_props" => false
                           })
                       }) = response
      end

      test "can change domain name and tracker script configuration together (merging updated keys with previous configuration)",
           %{conn: conn, site: site} do
        old_domain = site.domain
        assert old_domain != "new.example.com"

        conn =
          put(conn, "/api/v1/sites/#{site.domain}", %{
            "domain" => "new.example.com",
            "tracker_script_configuration" => %{
              "form_submissions" => true
            }
          })

        response = json_response(conn, 200)

        assert_matches ^strict_map(%{
                         "domain" => "new.example.com",
                         "timezone" => "UTC",
                         "custom_properties" => [],
                         "tracker_script_configuration" =>
                           ^strict_map(%{
                             "id" => ^any(:string),
                             "installation_type" => nil,
                             "track_404_pages" => false,
                             "hash_based_routing" => false,
                             "outbound_links" => false,
                             "file_downloads" => false,
                             "revenue_tracking" => false,
                             "tagged_events" => false,
                             "form_submissions" => true,
                             "pageview_props" => false
                           })
                       }) = response

        site = Repo.reload!(site)

        assert site.domain == "new.example.com"
        assert site.domain_changed_from == old_domain
      end

      test "domain name change and tracker script configuration update are run as a transaction: if updating the configuration fails, the domain change is rolled back",
           %{conn: conn, site: site} do
        old_domain = site.domain
        assert old_domain != "new.example.com"

        conn =
          put(conn, "/api/v1/sites/#{site.domain}", %{
            "domain" => "new.example.com",
            "tracker_script_configuration" => %{
              "installation_type" => "an invalid value",
              "form_submissions" => true
            }
          })

        assert json_response(conn, 400) == %{
                 "error" => "tracker_script_configuration.installation_type: is invalid"
               }

        site = Repo.reload!(site)

        assert site.domain == old_domain
        assert site.domain_changed_from == nil
      end

      test "fails when team does not match team-scoped key", %{conn: conn, user: user, site: site} do
        another_team = new_user() |> subscribe_to_business_plan() |> team_of()
        add_member(another_team, user: user, role: :admin)
        api_key = insert(:api_key, user: user, team: another_team, scopes: ["sites:provision:*"])
        conn = Plug.Conn.put_req_header(conn, "authorization", "Bearer #{api_key.key}")

        old_domain = site.domain
        assert old_domain != "new.example.com"

        conn =
          put(conn, "/api/v1/sites/#{old_domain}", %{
            "domain" => "new.example.com"
          })

        assert json_response(conn, 404) == %{
                 "error" => "Site could not be found"
               }
      end

      test "fails when neither 'domain' nor 'tracker_script_configuration' is provided", %{
        conn: conn,
        site: site
      } do
        conn =
          put(conn, "/api/v1/sites/#{site.domain}", %{"foo" => "bar"})

        assert json_response(conn, 400) == %{
                 "error" =>
                   "Payload must contain at least one of the parameters 'domain', 'tracker_script_configuration'"
               }
      end

      test "fails when domain parameter is invalid", %{conn: conn, site: site} do
        conn = put(conn, "/api/v1/sites/#{site.domain}", %{"domain" => 123})

        assert json_response(conn, 400) == %{
                 "error" => "domain: is invalid"
               }
      end

      test "can't make a no-op domain change", %{conn: conn, site: site} do
        conn =
          put(conn, "/api/v1/sites/#{site.domain}", %{
            "domain" => site.domain
          })

        assert json_response(conn, 400) == %{
                 "error" => "domain: New domain must be different than the current one"
               }
      end

      test "fails when tracker script configuration parameter is invalid", %{
        conn: conn,
        site: site
      } do
        conn =
          put(conn, "/api/v1/sites/#{site.domain}", %{
            "tracker_script_configuration" => %{
              "form_submissions" => "an invalid value"
            }
          })

        assert json_response(conn, 400) == %{
                 "error" => "tracker_script_configuration.form_submissions: is invalid"
               }
      end
    end
  end
end
