defmodule PlausibleWeb.Plugins.API.Controllers.GoalsTest do
  use PlausibleWeb.PluginsAPICase, async: true
  use Plausible.Teams.Test
  alias PlausibleWeb.Plugins.API.Schemas

  describe "examples" do
    test "Goal.CreateRequest.Revenue" do
      assert_schema(
        Schemas.Goal.CreateRequest.Revenue.schema().example,
        "Goal.CreateRequest.Revenue",
        spec()
      )
    end

    test "Goal.CreateRequest.Pageview" do
      assert_schema(
        Schemas.Goal.CreateRequest.Pageview.schema().example,
        "Goal.CreateRequest.Pageview",
        spec()
      )
    end

    test "Goal.CreateRequest.CustomEvent" do
      assert_schema(
        Schemas.Goal.CreateRequest.CustomEvent.schema().example,
        "Goal.CreateRequest.CustomEvent",
        spec()
      )
    end
  end

  describe "unauthorized calls" do
    for {method, url} <- [
          {:get, Routes.plugins_api_goals_url(PlausibleWeb.Endpoint, :index)},
          {:get, Routes.plugins_api_goals_url(PlausibleWeb.Endpoint, :get, 1)},
          {:put, Routes.plugins_api_goals_url(PlausibleWeb.Endpoint, :create, %{})},
          {:delete, Routes.plugins_api_goals_url(PlausibleWeb.Endpoint, :delete, 1)},
          {:delete, Routes.plugins_api_goals_url(PlausibleWeb.Endpoint, :delete_bulk, %{})}
        ] do
      test "unauthorized call: #{method} #{url}", %{conn: conn} do
        conn
        |> unquote(method)(unquote(url))
        |> json_response(401)
        |> assert_schema("UnauthorizedError", spec())
      end
    end
  end

  describe "business tier" do
    @tag :ee_only
    test "fails on revenue goal creation attempt with insufficient plan", %{
      site: site,
      token: token,
      conn: conn
    } do
      [owner | _] = Plausible.Repo.preload(site, :owners).owners
      subscribe_to_growth_plan(owner)

      url = Routes.plugins_api_goals_url(PlausibleWeb.Endpoint, :create)

      payload = %{
        goal_type: "Goal.Revenue",
        goal: %{event_name: "Purchase", currency: "EUR"}
      }

      assert_request_schema(payload, "Goal.CreateRequest.Revenue", spec())

      conn
      |> authenticate(site.domain, token)
      |> put_req_header("content-type", "application/json")
      |> put(url, payload)
      |> json_response(402)
      |> assert_schema("PaymentRequiredError", spec())
    end

    @tag :ee_only
    test "fails on bulk revenue goal creation attempt with insufficient plan", %{
      site: site,
      token: token,
      conn: conn
    } do
      [owner | _] = Plausible.Repo.preload(site, :owners).owners
      subscribe_to_growth_plan(owner)

      url = Routes.plugins_api_goals_url(PlausibleWeb.Endpoint, :create)

      payload = %{
        goals: [
          %{
            goal_type: "Goal.CustomEvent",
            goal: %{event_name: "Signup"}
          },
          %{
            goal_type: "Goal.Revenue",
            goal: %{event_name: "Purchase", currency: "EUR"}
          },
          %{
            goal_type: "Goal.Pageview",
            goal: %{path: "/checkout"}
          }
        ]
      }

      conn
      |> authenticate(site.domain, token)
      |> put_req_header("content-type", "application/json")
      |> put(url, payload)
      |> json_response(402)
      |> assert_schema("PaymentRequiredError", spec())
    end
  end

  describe "put /goals - create a single goal" do
    test "validates input according to the schema", %{conn: conn, token: token, site: site} do
      url = Routes.plugins_api_goals_url(PlausibleWeb.Endpoint, :create)

      conn
      |> authenticate(site.domain, token)
      |> put_req_header("content-type", "application/json")
      |> put(url, %{goal_type: "Goal.SomeTypo", goal: %{event_name: "Signup"}})
      |> json_response(422)
      |> assert_schema("UnprocessableEntityError", spec())
    end

    test "creates a custom event goal", %{conn: conn, token: token, site: site} do
      url = Routes.plugins_api_goals_url(PlausibleWeb.Endpoint, :create)

      payload = %{goal_type: "Goal.CustomEvent", goal: %{event_name: "Signup"}}

      assert_request_schema(payload, "Goal.CreateRequest.CustomEvent", spec())

      conn =
        conn
        |> authenticate(site.domain, token)
        |> put_req_header("content-type", "application/json")
        |> put(url, payload)

      resp =
        conn
        |> json_response(201)
        |> assert_schema("Goal.ListResponse", spec())

      resp.goals
      |> List.first()
      |> assert_schema("Goal.CustomEvent", spec())

      [location] = get_resp_header(conn, "location")

      assert location ==
               Routes.plugins_api_goals_url(
                 PlausibleWeb.Endpoint,
                 :get,
                 List.first(resp.goals).goal.id
               )

      assert [%{event_name: "Signup"}] = Plausible.Goals.for_site(site)
    end

    @tag :ee_only
    test "creates a revenue goal", %{conn: conn, token: token, site: site} do
      url = Routes.plugins_api_goals_url(PlausibleWeb.Endpoint, :create)

      payload = %{
        goal_type: "Goal.Revenue",
        goal: %{event_name: "Purchase", currency: "EUR"}
      }

      assert_request_schema(payload, "Goal.CreateRequest.Revenue", spec())

      conn =
        conn
        |> authenticate(site.domain, token)
        |> put_req_header("content-type", "application/json")
        |> put(url, payload)

      resp =
        conn
        |> json_response(201)
        |> assert_schema("Goal.ListResponse", spec())

      resp.goals
      |> List.first()
      |> assert_schema("Goal.Revenue", spec())

      [location] = get_resp_header(conn, "location")

      assert location ==
               Routes.plugins_api_goals_url(
                 PlausibleWeb.Endpoint,
                 :get,
                 List.first(resp.goals).goal.id
               )

      assert [%{event_name: "Purchase", currency: :EUR}] = Plausible.Goals.for_site(site)
    end

    @tag :ee_only
    test "fails to create a revenue goal with unknown currency", %{
      conn: conn,
      token: token,
      site: site
    } do
      url = Routes.plugins_api_goals_url(PlausibleWeb.Endpoint, :create)

      payload = %{
        goal_type: "Goal.Revenue",
        goal: %{event_name: "Purchase", currency: "DFJKHJESFHYU"}
      }

      assert_request_schema(payload, "Goal.CreateRequest.Revenue", spec())

      conn =
        conn
        |> authenticate(site.domain, token)
        |> put_req_header("content-type", "application/json")
        |> put(url, payload)

      resp =
        conn
        |> json_response(422)
        |> assert_schema("UnprocessableEntityError", spec())

      assert [%{detail: "currency: is invalid"}] = resp.errors
    end

    @tag :ee_only
    test "edge case - revenue goal exists under the same name and different currency", %{
      conn: conn,
      token: token,
      site: site
    } do
      url = Routes.plugins_api_goals_url(PlausibleWeb.Endpoint, :create)

      {:ok, _} = Plausible.Goals.create(site, %{"event_name" => "Purchase", "currency" => "USD"})

      conn =
        conn
        |> authenticate(site.domain, token)
        |> put_req_header("content-type", "application/json")
        |> put(url, %{goal_type: "Goal.Revenue", goal: %{event_name: "Purchase", currency: "EUR"}})

      resp =
        conn
        |> json_response(422)
        |> assert_schema("UnprocessableEntityError", spec())

      assert [%{detail: "event_name: 'Purchase' (with currency: USD) has already been taken"}] =
               resp.errors
    end

    test "creates a pageview goal", %{conn: conn, token: token, site: site} do
      url = Routes.plugins_api_goals_url(PlausibleWeb.Endpoint, :create)

      payload = %{goal_type: "Goal.Pageview", goal: %{path: "/checkout"}}
      assert_request_schema(payload, "Goal.CreateRequest.Pageview", spec())

      conn =
        conn
        |> authenticate(site.domain, token)
        |> put_req_header("content-type", "application/json")
        |> put(url, payload)

      resp =
        conn
        |> json_response(201)
        |> assert_schema("Goal.ListResponse", spec())

      resp.goals
      |> List.first()
      |> assert_schema("Goal.Pageview", spec())

      [location] = get_resp_header(conn, "location")

      assert location ==
               Routes.plugins_api_goals_url(
                 PlausibleWeb.Endpoint,
                 :get,
                 List.first(resp.goals).goal.id
               )

      assert [%{page_path: "/checkout"}] = Plausible.Goals.for_site(site)
    end

    test "is idempotent", %{conn: conn, token: token, site: site} do
      url = Routes.plugins_api_goals_url(PlausibleWeb.Endpoint, :create)

      initial_conn =
        conn
        |> authenticate(site.domain, token)
        |> put_req_header("content-type", "application/json")

      resp1 =
        initial_conn
        |> put(url, %{goal_type: "Goal.Pageview", goal: %{path: "/checkout"}})
        |> json_response(201)
        |> assert_schema("Goal.ListResponse", spec())

      resp1.goals
      |> List.first()
      |> assert_schema("Goal.Pageview", spec())

      assert initial_conn
             |> put(url, %{goal_type: "Goal.Pageview", goal: %{path: "/checkout"}})
             |> json_response(201)
             |> assert_schema("Goal.ListResponse", spec()) == resp1
    end
  end

  describe "put /goals - bulk creation" do
    @tag :ee_only
    test "creates a goal of each type", %{conn: conn, token: token, site: site} do
      url = Routes.plugins_api_goals_url(PlausibleWeb.Endpoint, :create)

      payload = %{
        goals: [
          %{
            goal_type: "Goal.CustomEvent",
            goal: %{event_name: "Signup"}
          },
          %{
            goal_type: "Goal.Revenue",
            goal: %{event_name: "Purchase", currency: "EUR"}
          },
          %{
            goal_type: "Goal.Pageview",
            goal: %{path: "/checkout"}
          }
        ]
      }

      assert_request_schema(payload, "Goal.CreateRequest.BulkGetOrCreate", spec())

      conn =
        conn
        |> authenticate(site.domain, token)
        |> put_req_header("content-type", "application/json")
        |> put(url, payload)

      resp =
        conn
        |> json_response(201)
        |> assert_schema("Goal.ListResponse", spec())

      [l1, l2, l3] = get_resp_header(conn, "location")

      assert l1 ==
               Routes.plugins_api_goals_url(
                 PlausibleWeb.Endpoint,
                 :get,
                 Enum.at(resp.goals, 0).goal.id
               )

      assert l2 ==
               Routes.plugins_api_goals_url(
                 PlausibleWeb.Endpoint,
                 :get,
                 Enum.at(resp.goals, 1).goal.id
               )

      assert l3 ==
               Routes.plugins_api_goals_url(
                 PlausibleWeb.Endpoint,
                 :get,
                 Enum.at(resp.goals, 2).goal.id
               )

      assert Enum.count(resp.goals) == 3

      assert [
               %{page_path: "/checkout"},
               %{event_name: "Purchase", currency: :EUR},
               %{event_name: "Signup"}
             ] = Plausible.Goals.for_site(site)
    end

    test "no more than 8 goals can be created in bulk", %{conn: conn, token: token, site: site} do
      # if this test fails due to implementation change, consider what to do with the pagination meta
      # object returned in the response and also revise how funnels are created based on a list of goals
      # - the funnels creation endpoint will likely reuse this schema's constraints
      url = Routes.plugins_api_goals_url(PlausibleWeb.Endpoint, :create)

      payload =
        Enum.map(1..9, fn i ->
          %{goal_type: "Goal.CustomEvent", goal: %{event_name: "Bulk Goal ##{i}"}}
        end)

      resp =
        conn
        |> authenticate(site.domain, token)
        |> put_req_header("content-type", "application/json")
        |> put(url, %{
          goals: payload
        })
        |> json_response(422)
        |> assert_schema("UnprocessableEntityError", spec())

      assert %Schemas.Error{
               detail: "Array length 9 is larger than maxItems: 8"
             } in resp.errors
    end

    @tag :ee_only
    test "is idempotent", %{conn: conn, token: token, site: site} do
      url = Routes.plugins_api_goals_url(PlausibleWeb.Endpoint, :create)

      initial_conn =
        conn
        |> authenticate(site.domain, token)
        |> put_req_header("content-type", "application/json")

      payload = [
        %{
          goal_type: "Goal.CustomEvent",
          goal: %{event_name: "Signup"}
        },
        %{
          goal_type: "Goal.Revenue",
          goal: %{event_name: "Purchase", currency: "EUR"}
        },
        %{
          goal_type: "Goal.Pageview",
          goal: %{path: "/checkout"}
        }
      ]

      initial_conn
      |> put(url, %{goals: payload})
      |> json_response(201)
      |> assert_schema("Goal.ListResponse", spec())

      initial_conn
      |> put(url, %{goals: payload})
      |> json_response(201)
      |> assert_schema("Goal.ListResponse", spec())
    end

    @tag :ee_only
    test "edge case - revenue goals exist under the same name and different currency", %{
      conn: conn,
      token: token,
      site: site
    } do
      url = Routes.plugins_api_goals_url(PlausibleWeb.Endpoint, :create)

      initial_conn =
        conn
        |> authenticate(site.domain, token)
        |> put_req_header("content-type", "application/json")

      payload1 = [%{goal_type: "Goal.Revenue", goal: %{event_name: "Purchase", currency: "EUR"}}]
      payload2 = [%{goal_type: "Goal.Revenue", goal: %{event_name: "Purchase", currency: "USD"}}]

      initial_conn
      |> put(url, %{goals: payload1})
      |> json_response(201)
      |> assert_schema("Goal.ListResponse", spec())

      resp =
        initial_conn
        |> put(url, %{goals: payload2})
        |> json_response(422)
        |> assert_schema("UnprocessableEntityError", spec())

      assert [%{detail: "event_name: 'Purchase' (with currency: EUR) has already been taken"}] =
               resp.errors
    end
  end

  describe "get /goals/:id" do
    test "validates input out of the box", %{conn: conn, token: token, site: site} do
      url = Routes.plugins_api_goals_url(PlausibleWeb.Endpoint, :get, "hello")

      resp =
        conn
        |> authenticate(site.domain, token)
        |> get(url)
        |> json_response(422)
        |> assert_schema("UnprocessableEntityError", spec())

      assert %{errors: [%{detail: "Invalid integer. Got: string"}]} = resp
    end

    @tag :ee_only
    test "retrieves revenue goal by ID", %{conn: conn, site: site, token: token} do
      {:ok, goal} =
        Plausible.Goals.create(site, %{"event_name" => "Purchase", "currency" => "EUR"})

      url = Routes.plugins_api_goals_url(PlausibleWeb.Endpoint, :get, goal.id)

      resp =
        conn
        |> authenticate(site.domain, token)
        |> get(url)
        |> json_response(200)
        |> assert_schema("Goal", spec())
        |> assert_schema("Goal.Revenue", spec())

      assert resp.goal.id == goal.id
      assert resp.goal_type == "Goal.Revenue"
      assert resp.goal.display_name == "Purchase"
    end

    test "retrieves pageview goal by ID", %{conn: conn, site: site, token: token} do
      {:ok, goal} = Plausible.Goals.create(site, %{"page_path" => "/checkout"})

      url = Routes.plugins_api_goals_url(PlausibleWeb.Endpoint, :get, goal.id)

      resp =
        conn
        |> authenticate(site.domain, token)
        |> get(url)
        |> json_response(200)
        |> assert_schema("Goal", spec())
        |> assert_schema("Goal.Pageview", spec())

      assert resp.goal.id == goal.id
      assert resp.goal_type == "Goal.Pageview"
      assert resp.goal.display_name == "Visit /checkout"
    end

    test "retrieves custom event goal by ID", %{conn: conn, site: site, token: token} do
      {:ok, goal} = Plausible.Goals.create(site, %{"event_name" => "Signup"})

      url = Routes.plugins_api_goals_url(PlausibleWeb.Endpoint, :get, goal.id)

      resp =
        conn
        |> authenticate(site.domain, token)
        |> get(url)
        |> json_response(200)
        |> assert_schema("Goal", spec())
        |> assert_schema("Goal.CustomEvent", spec())

      assert resp.goal.id == goal.id
      assert resp.goal_type == "Goal.CustomEvent"
      assert resp.goal.display_name == "Signup"
    end
  end

  describe "get /goals" do
    test "returns an empty goals list if there's none", %{
      conn: conn,
      token: token,
      site: site
    } do
      url = Routes.plugins_api_goals_url(PlausibleWeb.Endpoint, :index)

      resp =
        conn
        |> authenticate(site.domain, token)
        |> get(url)
        |> json_response(200)
        |> assert_schema("Goal.ListResponse", spec())

      assert resp.goals == []
      assert resp.meta.pagination.has_next_page == false
      assert resp.meta.pagination.has_prev_page == false
      assert resp.meta.pagination.links == %{}
    end

    @tag :ee_only
    test "returns a list of goals of each possible goal type", %{
      conn: conn,
      site: site,
      token: token
    } do
      {:ok, g1} = Plausible.Goals.create(site, %{"event_name" => "Signup"})
      {:ok, g2} = Plausible.Goals.create(site, %{"event_name" => "Purchase", "currency" => "EUR"})
      {:ok, g3} = Plausible.Goals.create(site, %{"page_path" => "/checkout"})

      url = Routes.plugins_api_goals_url(PlausibleWeb.Endpoint, :index)

      resp =
        conn
        |> authenticate(site.domain, token)
        |> get(url)
        |> json_response(200)
        |> assert_schema("Goal.ListResponse", spec())

      assert [checkout, purchase, signup] = resp.goals
      assert checkout.goal.display_name == "Visit /checkout"
      assert checkout.goal.path == "/checkout"
      assert checkout.goal.id == g3.id
      assert checkout.goal_type == "Goal.Pageview"

      assert purchase.goal.display_name == "Purchase"
      assert purchase.goal.currency == "EUR"
      assert purchase.goal.event_name == "Purchase"
      assert purchase.goal.id == g2.id
      assert purchase.goal_type == "Goal.Revenue"

      assert signup.goal.display_name == "Signup"
      assert signup.goal.event_name == "Signup"
      assert signup.goal.id == g1.id
      assert signup.goal_type == "Goal.CustomEvent"
    end

    test "returns a list of goals with pagination", %{conn: conn, site: site, token: token} do
      for i <- 1..5 do
        insert(:goal, site: site, event_name: "Goal #{i}")
      end

      url = Routes.plugins_api_goals_url(PlausibleWeb.Endpoint, :index, limit: 2)

      initial_conn = authenticate(conn, site.domain, token)

      page1 =
        initial_conn
        |> get(url)
        |> json_response(200)
        |> assert_schema("Goal.ListResponse", spec())

      assert [%{goal: %{event_name: "Goal 5"}}, %{goal: %{event_name: "Goal 4"}}] = page1.goals
      assert page1.meta.pagination.has_next_page == true
      assert page1.meta.pagination.has_prev_page == false
      assert page1.meta.pagination.links.next
      refute page1.meta.pagination.links[:prev]

      page2 =
        initial_conn
        |> get(page1.meta.pagination.links.next.url)
        |> json_response(200)
        |> assert_schema("Goal.ListResponse", spec())

      assert [%{goal: %{event_name: "Goal 3"}}, %{goal: %{event_name: "Goal 2"}}] = page2.goals

      assert page2.meta.pagination.has_next_page == true
      assert page2.meta.pagination.has_prev_page == true
      assert page2.meta.pagination.links.next
      assert page2.meta.pagination.links.prev

      assert ^page1 =
               initial_conn
               |> get(page2.meta.pagination.links.prev.url)
               |> json_response(200)
               |> assert_schema("Goal.ListResponse", spec())
    end
  end

  describe "delete /goals/:id" do
    test "deletes goal by id", %{conn: conn, site: site, token: token} do
      {:ok, %{id: goal_id}} =
        Plausible.Goals.create(site, %{"event_name" => "Purchase", "currency" => "USD"})

      url = Routes.plugins_api_goals_url(PlausibleWeb.Endpoint, :delete, goal_id)

      conn
      |> authenticate(site.domain, token)
      |> delete(url)
      |> response(204)

      refute Plausible.Repo.exists?(Plausible.Goal)
    end

    test "is idempotent", %{conn: conn, site: site, token: token} do
      url = Routes.plugins_api_goals_url(PlausibleWeb.Endpoint, :delete, 666)

      conn
      |> authenticate(site.domain, token)
      |> delete(url)
      |> response(204)
    end
  end

  describe "delete - bulk" do
    test "delete multiple goals", %{conn: conn, site: site, token: token} do
      {:ok, g1} =
        Plausible.Goals.create(site, %{"event_name" => "Purchase", "currency" => "USD"})

      {:ok, g2} =
        Plausible.Goals.create(site, %{"event_name" => "Signup"})

      {:ok, g3} =
        Plausible.Goals.create(site, %{"page_path" => "/home"})

      url = Routes.plugins_api_goals_url(PlausibleWeb.Endpoint, :delete_bulk)

      payload = %{
        goal_ids: [
          g1.id,
          g2.id,
          g3.id
        ]
      }

      conn
      |> authenticate(site.domain, token)
      |> put_req_header("content-type", "application/json")
      |> delete(url, payload)
      |> response(204)

      refute Plausible.Repo.exists?(Plausible.Goal)
    end
  end
end
