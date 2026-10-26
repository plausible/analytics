defmodule PlausibleWeb.Api.Internal.FunnelsControllerTest do
  use PlausibleWeb.ConnCase, async: true
  @moduletag :ee_only

  on_ee do
    alias Plausible.{Funnel, Funnels, Goals}

    setup [:create_user, :log_in, :create_site]

    setup %{site: site} do
      {:ok, g1} = Goals.create(site, %{"page_path" => "/blog"})
      {:ok, g2} = Goals.create(site, %{"event_name" => "Signup"})
      {:ok, goals: [g1, g2]}
    end

    describe "permissions" do
      for role <- [:viewer] do
        test "forbids #{role} guests from managing funnels", %{conn: conn, user: user} do
          site = new_site()
          add_guest(site, user: user, role: unquote(role))

          {:ok, funnel} =
            Funnels.create(site, "Funnel", [%{"page_path" => "/a"}, %{"page_path" => "/b"}])

          assert %{"error" => "Not enough permissions to manage funnels"} =
                   conn
                   |> post("/api/#{site.domain}/funnels", %{"name" => "x", "steps" => []})
                   |> json_response(403)

          assert conn |> get("/api/#{site.domain}/funnels/#{funnel.id}") |> json_response(403)

          assert conn
                 |> patch("/api/#{site.domain}/funnels/#{funnel.id}", %{"name" => "y"})
                 |> json_response(403)

          assert conn |> delete("/api/#{site.domain}/funnels/#{funnel.id}") |> json_response(403)
          assert Funnels.get(site, funnel.id)
        end
      end

      test "allows guest editors", %{conn: conn, user: user} do
        site = new_site()
        add_guest(site, user: user, role: :editor)

        assert %{"name" => "Funnel"} =
                 conn
                 |> post("/api/#{site.domain}/funnels", %{
                   "name" => "Funnel",
                   "steps" => [%{"page_path" => "/a"}, %{"page_path" => "/b"}]
                 })
                 |> json_response(200)
      end

      test "forbids shared link visitors", %{site: site} do
        link = insert(:shared_link, site: site)

        assert build_conn()
               |> post("/api/#{site.domain}/funnels?auth=#{link.slug}", %{
                 "name" => "Funnel",
                 "steps" => [%{"page_path" => "/a"}, %{"page_path" => "/b"}]
               })
               |> json_response(403)
      end
    end

    describe "POST /api/:domain/funnels" do
      test "creates a funnel from goal and dynamic steps", %{
        conn: conn,
        site: site,
        goals: [g1, g2]
      } do
        resp =
          conn
          |> post("/api/#{site.domain}/funnels", %{
            "name" => "Blog to purchase",
            "funnel_type" => "strict",
            "steps" => [
              %{"goal_id" => g1.id},
              %{"page_path" => "/pricing*"},
              %{"goal_id" => g2.id},
              %{"event_name" => "Purchase", "currency" => "USD"}
            ]
          })
          |> json_response(200)

        assert %{
                 "id" => id,
                 "name" => "Blog to purchase",
                 "funnel_type" => "strict",
                 "steps_count" => 4
               } = resp

        funnel = Funnels.get(site, id)
        assert funnel.funnel_type == :strict

        assert [
                 %{goal_id: g1_id},
                 %{page_path: "/pricing*"},
                 %{goal_id: g2_id},
                 %{event_name: "Purchase", currency: :USD}
               ] = Funnel.steps(funnel)

        assert g1_id == g1.id
        assert g2_id == g2.id
      end

      test "defaults to sequential funnel type", %{conn: conn, site: site, goals: [g1, g2]} do
        assert %{"funnel_type" => "sequential"} =
                 conn
                 |> post("/api/#{site.domain}/funnels", %{
                   "name" => "Funnel",
                   "steps" => [%{"goal_id" => g1.id}, %{"goal_id" => g2.id}]
                 })
                 |> json_response(200)
      end

      test "rejects invalid input", %{conn: conn, site: site, goals: [g1, g2]} do
        {:ok, other_goal} = Goals.create(new_site(), %{"event_name" => "Signup"})

        cases = [
          {[%{"goal_id" => g1.id}], "between 2 and 8 steps"},
          {[%{"goal_id" => g1.id}, %{"goal_id" => other_goal.id}], "goal that doesn't exist"},
          {[%{"goal_id" => g1.id}, %{"event_name" => "__journey_end__"}], "steps is invalid"},
          {[%{"goal_id" => g1.id}, %{"goal_id" => g1.id}], "steps must be unique"},
          {[%{"goal_id" => g1.id}, %{"page_path" => "/a", "event_name" => "A"}],
           "step event_name cannot co-exist with page_path"}
        ]

        for {steps, message} <- cases do
          assert %{"error" => error} =
                   conn
                   |> post("/api/#{site.domain}/funnels", %{"name" => "Funnel", "steps" => steps})
                   |> json_response(400)

          assert error =~ message
        end

        assert %{"error" => "Invalid funnel type"} =
                 conn
                 |> post("/api/#{site.domain}/funnels", %{
                   "name" => "Funnel",
                   "funnel_type" => "bogus",
                   "steps" => [%{"goal_id" => g1.id}, %{"goal_id" => g2.id}]
                 })
                 |> json_response(400)

        assert Funnels.list(site) == []
      end

      test "rejects duplicate names", %{conn: conn, site: site, goals: [g1, g2]} do
        {:ok, _} = Funnels.create(site, "Funnel", [g1, g2])

        assert %{"error" => "name has already been taken"} =
                 conn
                 |> post("/api/#{site.domain}/funnels", %{
                   "name" => "Funnel",
                   "steps" => [%{"goal_id" => g1.id}, %{"goal_id" => g2.id}]
                 })
                 |> json_response(400)
      end

      test "requires a plan with funnels", %{conn: conn, user: user, site: site, goals: [g1, g2]} do
        user
        |> team_of()
        |> Plausible.Teams.Team.end_trial()
        |> Plausible.Repo.update!()

        assert conn
               |> post("/api/#{site.domain}/funnels", %{
                 "name" => "Funnel",
                 "steps" => [%{"goal_id" => g1.id}, %{"goal_id" => g2.id}]
               })
               |> json_response(402)
      end
    end

    describe "GET /api/:domain/funnels/:funnel_id" do
      test "returns the funnel definition", %{conn: conn, site: site, goals: [g1, _]} do
        {:ok, scroll_goal} =
          Goals.create(site, %{
            "page_path" => "/blog",
            "scroll_threshold" => 50,
            "display_name" => "Read blog"
          })

        {:ok, funnel} =
          Funnels.create(site, "Funnel", [g1, %{"event_name" => "Signup"}, scroll_goal],
            funnel_type: :flexible
          )

        assert %{
                 "id" => id,
                 "name" => "Funnel",
                 "funnel_type" => "flexible",
                 "steps_count" => 3,
                 "steps" => [
                   %{
                     "goal_id" => g1_id,
                     "label" => "Visit /blog",
                     "page_path" => "/blog",
                     "event_name" => nil,
                     "goal_kind" => nil
                   },
                   %{"goal_id" => nil, "label" => "Signup", "event_name" => "Signup"},
                   %{"goal_id" => scroll_id, "label" => "Read blog", "goal_kind" => "scroll"}
                 ]
               } = conn |> get("/api/#{site.domain}/funnels/#{funnel.id}") |> json_response(200)

        assert id == funnel.id
        assert g1_id == g1.id
        assert scroll_id == scroll_goal.id
      end

      test "returns 404 for unknown and foreign funnels", %{conn: conn, site: site} do
        other_site = new_site()

        {:ok, other_funnel} =
          Funnels.create(other_site, "Foreign", [%{"page_path" => "/a"}, %{"page_path" => "/b"}])

        assert conn |> get("/api/#{site.domain}/funnels/999999") |> json_response(404)
        assert conn |> get("/api/#{site.domain}/funnels/abc") |> json_response(404)
        assert conn |> get("/api/#{site.domain}/funnels/#{other_funnel.id}") |> json_response(404)
      end
    end

    describe "PATCH /api/:domain/funnels/:funnel_id" do
      test "renames a funnel and changes its type without touching steps", %{
        conn: conn,
        site: site,
        goals: [g1, g2]
      } do
        {:ok, funnel} = Funnels.create(site, "Funnel", [g1, %{"page_path" => "/x"}, g2])

        assert %{"name" => "Renamed", "funnel_type" => "strict", "steps_count" => 3} =
                 conn
                 |> patch("/api/#{site.domain}/funnels/#{funnel.id}", %{
                   "name" => "Renamed",
                   "funnel_type" => "strict"
                 })
                 |> json_response(200)

        funnel = Funnels.get(site, funnel.id)
        assert funnel.name == "Renamed"
        assert funnel.funnel_type == :strict
        assert length(Funnel.steps(funnel)) == 3
      end

      test "replaces steps", %{conn: conn, site: site, goals: [g1, g2]} do
        {:ok, funnel} = Funnels.create(site, "Funnel", [g1, g2])

        assert %{"name" => "Funnel", "steps_count" => 3} =
                 conn
                 |> patch("/api/#{site.domain}/funnels/#{funnel.id}", %{
                   "steps" => [
                     %{"goal_id" => g2.id},
                     %{"page_path" => "/pricing"},
                     %{"goal_id" => g1.id}
                   ]
                 })
                 |> json_response(200)

        assert [%{goal_id: first}, %{page_path: "/pricing"}, %{goal_id: last}] =
                 site |> Funnels.get(funnel.id) |> Funnel.steps()

        assert {first, last} == {g2.id, g1.id}
      end

      test "returns 400 on invalid steps", %{conn: conn, site: site, goals: [g1, g2]} do
        {:ok, funnel} = Funnels.create(site, "Funnel", [g1, g2])

        assert %{"error" => error} =
                 conn
                 |> patch("/api/#{site.domain}/funnels/#{funnel.id}", %{
                   "steps" => [%{"goal_id" => g1.id}]
                 })
                 |> json_response(400)

        assert error =~ "at least 2"
      end
    end

    describe "DELETE /api/:domain/funnels/:funnel_id" do
      test "deletes a funnel", %{conn: conn, site: site, goals: [g1, g2]} do
        {:ok, funnel} = Funnels.create(site, "Funnel", [g1, g2])

        assert %{"name" => "Funnel"} =
                 conn |> delete("/api/#{site.domain}/funnels/#{funnel.id}") |> json_response(200)

        refute Funnels.get(site, funnel.id)
        assert conn |> delete("/api/#{site.domain}/funnels/#{funnel.id}") |> json_response(404)
      end
    end
  end
end
