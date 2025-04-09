defmodule PlausibleWeb.Plugins.API.Controllers.CustomPropsTest do
  use PlausibleWeb.PluginsAPICase, async: true
  use Plausible.Teams.Test
  alias PlausibleWeb.Plugins.API.Schemas

  describe "examples" do
    test "CustomProp" do
      assert_schema(
        Schemas.CustomProp.schema().example,
        "CustomProp",
        spec()
      )
    end

    test "CustomProp.CreateRequest" do
      assert_schema(
        Schemas.CustomProp.EnableRequest.schema().example,
        "CustomProp.EnableRequest",
        spec()
      )
    end
  end

  describe "unauthorized calls" do
    for {method, url} <- [
          {:put, Routes.plugins_api_custom_props_url(PlausibleWeb.Endpoint, :enable)},
          {:delete, Routes.plugins_api_custom_props_url(PlausibleWeb.Endpoint, :disable)}
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
    @describetag :ee_only

    test "allows prop enable for special key", %{
      site: site,
      token: token,
      conn: conn
    } do
      [owner | _] = Plausible.Repo.preload(site, :owners).owners
      subscribe_to_growth_plan(owner)

      url = Routes.plugins_api_custom_props_url(PlausibleWeb.Endpoint, :enable)

      payload = %{
        custom_prop: %{key: "search_query"}
      }

      assert_request_schema(payload, "CustomProp.EnableRequest", spec())

      conn
      |> authenticate(site.domain, token)
      |> put_req_header("content-type", "application/json")
      |> put(url, payload)
      |> json_response(201)
      |> assert_schema("CustomProp.ListResponse", spec())
    end

    test "allows bulk prop enable for special keys", %{
      site: site,
      token: token,
      conn: conn
    } do
      [owner | _] = Plausible.Repo.preload(site, :owners).owners
      subscribe_to_growth_plan(owner)

      url = Routes.plugins_api_custom_props_url(PlausibleWeb.Endpoint, :enable)

      payload = %{
        custom_props: [
          %{
            custom_prop: %{key: "search_query"}
          },
          %{
            custom_prop: %{key: "url"}
          }
        ]
      }

      conn
      |> authenticate(site.domain, token)
      |> put_req_header("content-type", "application/json")
      |> put(url, payload)
      |> json_response(201)
      |> assert_schema("CustomProp.ListResponse", spec())
    end

    test "fails on custom prop enable attempt with insufficient plan", %{
      site: site,
      token: token,
      conn: conn
    } do
      [owner | _] = Plausible.Repo.preload(site, :owners).owners
      subscribe_to_growth_plan(owner)

      url = Routes.plugins_api_custom_props_url(PlausibleWeb.Endpoint, :enable)

      payload = %{
        custom_prop: %{key: "author"}
      }

      assert_request_schema(payload, "CustomProp.EnableRequest", spec())

      conn
      |> authenticate(site.domain, token)
      |> put_req_header("content-type", "application/json")
      |> put(url, payload)
      |> json_response(402)
      |> assert_schema("PaymentRequiredError", spec())
    end

    test "fails on bulk prop enable attempt with insufficient plan", %{
      site: site,
      token: token,
      conn: conn
    } do
      [owner | _] = Plausible.Repo.preload(site, :owners).owners
      subscribe_to_growth_plan(owner)

      url = Routes.plugins_api_custom_props_url(PlausibleWeb.Endpoint, :enable)

      payload = %{
        custom_props: [
          %{
            custom_prop: %{key: "author"}
          },
          %{
            custom_prop: %{key: "search_query"}
          },
          %{
            custom_prop: %{key: "category"}
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

  describe "put /custom_prop - enable single prop" do
    test "validates input according to the schema", %{conn: conn, token: token, site: site} do
      url = Routes.plugins_api_custom_props_url(PlausibleWeb.Endpoint, :enable)

      conn
      |> authenticate(site.domain, token)
      |> put_req_header("content-type", "application/json")
      |> put(url, %{custom_prop: %{typo: "author"}})
      |> json_response(422)
      |> assert_schema("UnprocessableEntityError", spec())
    end

    test "enables single custom prop", %{conn: conn, token: token, site: site} do
      url = Routes.plugins_api_custom_props_url(PlausibleWeb.Endpoint, :enable)

      payload = %{
        custom_prop: %{key: "author"}
      }

      assert_request_schema(payload, "CustomProp.EnableRequest", spec())

      conn =
        conn
        |> authenticate(site.domain, token)
        |> put_req_header("content-type", "application/json")
        |> put(url, payload)

      resp =
        conn
        |> json_response(201)
        |> assert_schema("CustomProp.ListResponse", spec())

      resp.custom_props
      |> List.first()
      |> assert_schema("CustomProp", spec())

      assert "author" in Plausible.Repo.reload!(site).allowed_event_props
    end

    test "is idempotent", %{conn: conn, token: token, site: site} do
      url = Routes.plugins_api_custom_props_url(PlausibleWeb.Endpoint, :enable)

      initial_conn =
        conn
        |> authenticate(site.domain, token)
        |> put_req_header("content-type", "application/json")

      resp1 =
        initial_conn
        |> put(
          url,
          %{
            custom_prop: %{key: "author"}
          }
        )
        |> json_response(201)
        |> assert_schema("CustomProp.ListResponse", spec())

      resp1.custom_props
      |> List.first()
      |> assert_schema("CustomProp", spec())

      assert initial_conn
             |> put(
               url,
               %{
                 custom_prop: %{key: "author"}
               }
             )
             |> json_response(201)
             |> assert_schema("CustomProp.ListResponse", spec()) == resp1
    end
  end

  describe "put /custom_props - bulk creation" do
    test "creates many custom props", %{conn: conn, token: token, site: site} do
      url = Routes.plugins_api_custom_props_url(PlausibleWeb.Endpoint, :enable)

      payload = %{
        custom_props: [
          %{
            custom_prop: %{key: "author"}
          },
          %{
            custom_prop: %{key: "rating"}
          },
          %{
            custom_prop: %{key: "category"}
          }
        ]
      }

      assert_request_schema(payload, "CustomProp.EnableRequest.BulkEnable", spec())

      conn =
        conn
        |> authenticate(site.domain, token)
        |> put_req_header("content-type", "application/json")
        |> put(url, payload)

      resp =
        conn
        |> json_response(201)
        |> assert_schema("CustomProp.ListResponse", spec())

      assert Enum.count(resp.custom_props) == 3

      assert [
               "author",
               "rating",
               "category"
             ] = Plausible.Repo.reload!(site).allowed_event_props
    end
  end

  describe "delete /custom_props" do
    test "disable one prop", %{conn: conn, site: site, token: token} do
      {:ok, ["author"]} = Plausible.Plugins.API.CustomProps.enable(site, "author")

      url = Routes.plugins_api_custom_props_url(PlausibleWeb.Endpoint, :enable)

      payload = %{custom_prop: %{key: "author"}}

      conn
      |> authenticate(site.domain, token)
      |> put_req_header("content-type", "application/json")
      |> delete(url, payload)
      |> response(204)

      assert Plausible.Repo.reload!(site).allowed_event_props == []
    end

    test "disable many props", %{conn: conn, site: site, token: token} do
      {:ok, [_, _, _]} =
        Plausible.Plugins.API.CustomProps.enable(site, ["author", "category", "third"])

      url = Routes.plugins_api_custom_props_url(PlausibleWeb.Endpoint, :enable)

      payload = %{
        custom_props: [
          %{custom_prop: %{key: "author"}},
          %{custom_prop: %{key: "category"}}
        ]
      }

      conn
      |> authenticate(site.domain, token)
      |> put_req_header("content-type", "application/json")
      |> delete(url, payload)
      |> response(204)

      assert Plausible.Repo.reload!(site).allowed_event_props == ["third"]
    end
  end
end
