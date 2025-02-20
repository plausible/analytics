defmodule PlausibleWeb.Plugins.API.Controllers.FunnelsTest do
  use PlausibleWeb.PluginsAPICase, async: true
  use Plausible
  use Plausible.Teams.Test

  @moduletag :ee_only

  on_ee do
    alias PlausibleWeb.Plugins.API.Schemas

    describe "examples" do
      test "Funnel" do
        assert_schema(
          Schemas.Funnel.schema().example,
          "Funnel",
          spec()
        )
      end

      test "Funnel.CreateRequest" do
        assert_schema(
          Schemas.Funnel.CreateRequest.schema().example,
          "Funnel.CreateRequest",
          spec()
        )
      end
    end

    describe "unauthorized calls" do
      for {method, url} <- [
            {:get, Routes.plugins_api_funnels_url(PlausibleWeb.Endpoint, :index)},
            {:get, Routes.plugins_api_funnels_url(PlausibleWeb.Endpoint, :get, 1)},
            {:put, Routes.plugins_api_funnels_url(PlausibleWeb.Endpoint, :create, %{})}
          ] do
        test "unauthorized call: #{method} #{url}", %{conn: conn} do
          conn
          |> unquote(method)(unquote(url))
          |> json_response(401)
          |> assert_schema("UnauthorizedError", spec())
        end
      end
    end

    describe "get /funnels/:id" do
      test "validates input out of the box", %{conn: conn, token: token, site: site} do
        url = Routes.plugins_api_funnels_url(PlausibleWeb.Endpoint, :get, "hello")

        resp =
          conn
          |> authenticate(site.domain, token)
          |> get(url)
          |> json_response(422)
          |> assert_schema("UnprocessableEntityError", spec())

        assert %{errors: [%{detail: "Invalid integer. Got: string"}]} = resp
      end

      test "retrieves no funnel on non-existing ID", %{conn: conn, token: token, site: site} do
        url = Routes.plugins_api_funnels_url(PlausibleWeb.Endpoint, :get, 9999)

        resp =
          conn
          |> authenticate(site.domain, token)
          |> get(url)
          |> json_response(404)
          |> assert_schema("NotFoundError", spec())

        assert %{errors: [%{detail: "Plugins API: resource not found"}]} = resp
      end

      test "retrieves funnel by ID", %{conn: conn, site: site, token: token} do
        {:ok, g1} = Plausible.Goals.create(site, %{"page_path" => "/product/123"})

        {:ok, g2} =
          Plausible.Goals.create(site, %{"event_name" => "Purchase", "currency" => "EUR"})

        {:ok, g3} = Plausible.Goals.create(site, %{"event_name" => "FiveStarReview"})

        {:ok, funnel} =
          Plausible.Funnels.create(
            site,
            "Peek & buy",
            [g1, g2, g3]
          )

        url = Routes.plugins_api_funnels_url(PlausibleWeb.Endpoint, :get, funnel.id)

        resp =
          conn
          |> authenticate(site.domain, token)
          |> get(url)
          |> json_response(200)
          |> assert_schema("Funnel", spec())

        assert resp.funnel.id == funnel.id
        assert resp.funnel.name == "Peek & buy"
        [s1, s2, s3] = resp.funnel.steps

        assert_schema(s1, "Goal.Pageview", spec())
        assert_schema(s2, "Goal.Revenue", spec())
        assert_schema(s3, "Goal.CustomEvent", spec())
      end
    end

    describe "get /funnels" do
      test "returns an empty funnels list if there's none", %{
        conn: conn,
        token: token,
        site: site
      } do
        url = Routes.plugins_api_funnels_url(PlausibleWeb.Endpoint, :index)

        resp =
          conn
          |> authenticate(site.domain, token)
          |> get(url)
          |> json_response(200)
          |> assert_schema("Funnel.ListResponse", spec())

        assert resp.funnels == []
        assert resp.meta.pagination.has_next_page == false
        assert resp.meta.pagination.has_prev_page == false
        assert resp.meta.pagination.links == %{}
      end

      test "retrieves all funnels", %{conn: conn, site: site, token: token} do
        {:ok, g1} = Plausible.Goals.create(site, %{"page_path" => "/product/123"})

        {:ok, g2} =
          Plausible.Goals.create(site, %{"event_name" => "Purchase", "currency" => "EUR"})

        {:ok, g3} = Plausible.Goals.create(site, %{"event_name" => "FiveStarReview"})

        for i <- 1..3 do
          {:ok, _} =
            Plausible.Funnels.create(
              site,
              "Funnel #{i}",
              [g1, g2, g3]
            )
        end

        url = Routes.plugins_api_funnels_url(PlausibleWeb.Endpoint, :index)

        resp =
          conn
          |> authenticate(site.domain, token)
          |> get(url)
          |> json_response(200)
          |> assert_schema("Funnel.ListResponse", spec())

        assert Enum.count(resp.funnels) == 3
      end

      test "retrieves funnels with pagination", %{conn: conn, site: site, token: token} do
        {:ok, g1} = Plausible.Goals.create(site, %{"page_path" => "/product/123"})

        {:ok, g2} =
          Plausible.Goals.create(site, %{"event_name" => "Purchase", "currency" => "EUR"})

        {:ok, g3} = Plausible.Goals.create(site, %{"event_name" => "FiveStarReview"})

        initial_order = Enum.shuffle([g1, g2, g3])

        for i <- 1..3 do
          {:ok, _} =
            Plausible.Funnels.create(
              site,
              "Funnel #{i}",
              initial_order
            )
        end

        url = Routes.plugins_api_funnels_url(PlausibleWeb.Endpoint, :index, limit: 2)
        initial_conn = authenticate(conn, site.domain, token)

        page1 =
          initial_conn
          |> get(url)
          |> json_response(200)
          |> assert_schema("Funnel.ListResponse", spec())

        assert Enum.count(page1.funnels) == 2
        assert page1.meta.pagination.has_next_page == true
        assert page1.meta.pagination.has_prev_page == false

        assert [%{funnel: %{steps: steps}}, %{funnel: %{steps: steps}}] = page1.funnels
        assert Enum.map(steps, & &1.goal.id) == Enum.map(initial_order, & &1.id)

        page2 =
          initial_conn
          |> get(page1.meta.pagination.links.next.url)
          |> json_response(200)
          |> assert_schema("Funnel.ListResponse", spec())

        assert Enum.count(page2.funnels) == 1
        assert page2.meta.pagination.has_next_page == false
        assert page2.meta.pagination.has_prev_page == true
      end
    end

    describe "put /funnels - funnel creation" do
      test "creates a funnel including its goals", %{conn: conn, token: token, site: site} do
        url = Routes.plugins_api_funnels_url(PlausibleWeb.Endpoint, :create)

        payload = %{
          funnel: %{
            name: "My Test Funnel",
            steps: [
              %{
                goal_type: "Goal.CustomEvent",
                goal: %{event_name: "Signup"}
              },
              %{
                goal_type: "Goal.Pageview",
                goal: %{path: "/checkout"}
              },
              %{
                goal_type: "Goal.Revenue",
                goal: %{event_name: "Purchase", currency: "EUR"}
              }
            ]
          }
        }

        assert_request_schema(payload, "Funnel.CreateRequest", spec())

        conn =
          conn
          |> authenticate(site.domain, token)
          |> put_req_header("content-type", "application/json")
          |> put(url, payload)

        resp =
          conn
          |> json_response(201)
          |> assert_schema("Funnel", spec())

        [location] = get_resp_header(conn, "location")

        assert location ==
                 Routes.plugins_api_funnels_url(PlausibleWeb.Endpoint, :get, resp.funnel.id)

        funnel = Plausible.Funnels.get(site, resp.funnel.id)

        assert funnel.name == resp.funnel.name
        assert funnel.site_id == site.id
        assert Enum.count(funnel.steps) == 3
      end

      test "fails for insufficient plan", %{conn: conn, token: token, site: site} do
        site = Plausible.Repo.preload(site, :owner)
        subscribe_to_growth_plan(site.owner)

        url = Routes.plugins_api_funnels_url(PlausibleWeb.Endpoint, :create)

        payload = %{
          funnel: %{
            name: "My Test Funnel",
            steps: [
              %{
                goal_type: "Goal.CustomEvent",
                goal: %{event_name: "Signup"}
              },
              %{
                goal_type: "Goal.Pageview",
                goal: %{path: "/checkout"}
              }
            ]
          }
        }

        assert_request_schema(payload, "Funnel.CreateRequest", spec())

        conn
        |> authenticate(site.domain, token)
        |> put_req_header("content-type", "application/json")
        |> put(url, payload)
        |> json_response(402)
        |> assert_schema("PaymentRequiredError", spec())
      end

      test "fails with only one step - guarded by the schema", %{
        conn: conn,
        token: token,
        site: site
      } do
        url = Routes.plugins_api_funnels_url(PlausibleWeb.Endpoint, :create)

        payload = %{
          funnel: %{
            name: "My Test Funnel",
            steps: [
              %{
                goal_type: "Goal.CustomEvent",
                goal: %{event_name: "Signup"}
              }
            ]
          }
        }

        resp =
          conn
          |> authenticate(site.domain, token)
          |> put_req_header("content-type", "application/json")
          |> put(url, payload)
          |> json_response(422)
          |> assert_schema("UnprocessableEntityError", spec())

        assert %{errors: [%{detail: "Array length 1 is smaller than minItems: 2"}]} = resp
      end

      test "is idempotent on full creation", %{conn: conn, token: token, site: site} do
        url = Routes.plugins_api_funnels_url(PlausibleWeb.Endpoint, :create)

        {:ok, _g1} =
          Plausible.Goals.create(site, %{"event_name" => "Purchase", "currency" => "EUR"})

        payload = %{
          funnel: %{
            name: "My Test Funnel",
            steps: [
              %{
                goal_type: "Goal.CustomEvent",
                goal: %{event_name: "Signup"}
              },
              %{
                goal_type: "Goal.Pageview",
                goal: %{path: "/checkout"}
              },
              %{
                goal_type: "Goal.Revenue",
                goal: %{event_name: "Purchase", currency: "EUR"}
              }
            ]
          }
        }

        assert_request_schema(payload, "Funnel.CreateRequest", spec())

        initial_conn =
          conn
          |> authenticate(site.domain, token)
          |> put_req_header("content-type", "application/json")

        resp1 =
          initial_conn
          |> put(url, payload)
          |> json_response(201)
          |> assert_schema("Funnel", spec())

        resp2 =
          initial_conn
          |> put(url, payload)
          |> json_response(201)
          |> assert_schema("Funnel", spec())

        assert resp1.funnel == resp2.funnel
      end

      test "edge case - different currency goal already exists", %{
        conn: conn,
        token: token,
        site: site
      } do
        url = Routes.plugins_api_funnels_url(PlausibleWeb.Endpoint, :create)

        {:ok, _g1} =
          Plausible.Goals.create(site, %{"event_name" => "Purchase", "currency" => "USD"})

        payload = %{
          funnel: %{
            name: "My Test Funnel",
            steps: [
              %{
                goal_type: "Goal.CustomEvent",
                goal: %{event_name: "Signup"}
              },
              %{
                goal_type: "Goal.Pageview",
                goal: %{path: "/checkout"}
              },
              %{
                goal_type: "Goal.Revenue",
                goal: %{event_name: "Purchase", currency: "EUR"}
              }
            ]
          }
        }

        assert_request_schema(payload, "Funnel.CreateRequest", spec())

        resp =
          conn
          |> authenticate(site.domain, token)
          |> put_req_header("content-type", "application/json")
          |> put(url, payload)
          |> json_response(422)
          |> assert_schema("UnprocessableEntityError", spec())

        assert [%{detail: "event_name: 'Purchase' (with currency: USD) has already been taken"}] =
                 resp.errors
      end
    end
  end
end
