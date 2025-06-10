defmodule PlausibleWeb.Plugins.API.Controllers.SharedLinksTest do
  use PlausibleWeb.PluginsAPICase, async: true

  describe "examples" do
    test "SharedLink" do
      assert_schema(
        Schemas.SharedLink.schema().example,
        "SharedLink",
        spec()
      )
    end
  end

  describe "unauthorized calls" do
    for {method, url} <- [
          {:get, Routes.plugins_api_shared_links_url(PlausibleWeb.Endpoint, :get, 1)},
          {:put, Routes.plugins_api_shared_links_url(PlausibleWeb.Endpoint, :create)},
          {:get, Routes.plugins_api_shared_links_url(PlausibleWeb.Endpoint, :index)}
        ] do
      test "unauthorized call: #{method} #{url}", %{conn: conn} do
        conn
        |> unquote(method)(unquote(url))
        |> json_response(401)
        |> assert_schema("UnauthorizedError", spec())
      end
    end
  end

  describe "get /shared_links/:id" do
    test "validates input out of the box", %{conn: conn, token: token, site: site} do
      url = Routes.plugins_api_shared_links_url(PlausibleWeb.Endpoint, :get, "hello")

      resp =
        conn
        |> authenticate(site.domain, token)
        |> get(url)
        |> json_response(422)
        |> assert_schema("UnprocessableEntityError", spec())

      assert %{errors: [%{detail: "Invalid integer. Got: string"}]} = resp
    end

    test "retrieve shared link by ID", %{conn: conn, site: site, token: token} do
      shared_link = insert(:shared_link, name: "Some Link Name", site: site)

      url = Routes.plugins_api_shared_links_url(PlausibleWeb.Endpoint, :get, shared_link.id)

      resp =
        conn
        |> authenticate(site.domain, token)
        |> get(url)
        |> json_response(200)
        |> assert_schema("SharedLink", spec())

      assert resp.shared_link.href ==
               "http://localhost:8000/share/#{URI.encode_www_form(site.domain)}?auth=#{shared_link.slug}"

      assert resp.shared_link.id == shared_link.id
      assert resp.shared_link.password_protected == false
      assert resp.shared_link.name == "Some Link Name"
    end

    test "fails to retrieve non-existing link", %{conn: conn, site: site, token: token} do
      url = Routes.plugins_api_shared_links_url(PlausibleWeb.Endpoint, :get, 666)

      conn
      |> authenticate(site.domain, token)
      |> get(url)
      |> json_response(404)
      |> assert_schema("NotFoundError", spec())
    end

    test "fails to retrieve link from another site", %{conn: conn, site: site, token: token} do
      shared_link = insert(:shared_link, name: "Some Link Name", site: build(:site))
      url = Routes.plugins_api_shared_links_url(PlausibleWeb.Endpoint, :get, shared_link.id)

      conn
      |> authenticate(site.domain, token)
      |> get(url)
      |> json_response(404)
      |> assert_schema("NotFoundError", spec())
    end
  end

  describe "put /shared_links" do
    test "successfully creates a shared link with the location header", %{
      conn: conn,
      site: site,
      token: token
    } do
      url = Routes.plugins_api_shared_links_url(PlausibleWeb.Endpoint, :create)

      initial_conn = authenticate(conn, site.domain, token)

      conn =
        initial_conn
        |> put_req_header("content-type", "application/json")
        |> put(url, %{
          shared_link: %{
            name: "My Shared Link"
          }
        })

      resp =
        conn
        |> json_response(201)
        |> assert_schema("SharedLink", spec())

      assert resp.shared_link.name == "My Shared Link"

      assert resp.shared_link.href =~
               "http://localhost:8000/share/#{URI.encode_www_form(site.domain)}?auth="

      [location] = get_resp_header(conn, "location")

      assert location ==
               Routes.plugins_api_shared_links_url(
                 PlausibleWeb.Endpoint,
                 :get,
                 resp.shared_link.id
               )

      assert ^resp =
               initial_conn
               |> get(location)
               |> json_response(200)
               |> assert_schema("SharedLink", spec())
    end

    test "create is idempotent", %{
      conn: conn,
      site: site,
      token: token
    } do
      url = Routes.plugins_api_shared_links_url(PlausibleWeb.Endpoint, :create)

      initial_conn = authenticate(conn, site.domain, token)

      create = fn ->
        initial_conn
        |> put_req_header("content-type", "application/json")
        |> put(url, %{
          shared_link: %{
            name: "My Shared Link"
          }
        })
      end

      conn = create.()

      resp =
        conn
        |> json_response(201)
        |> assert_schema("SharedLink", spec())

      id = resp.shared_link.id

      conn = create.()

      assert ^id =
               conn
               |> json_response(201)
               |> Map.fetch!("shared_link")
               |> Map.fetch!("id")
    end

    test "validates input out of the box", %{conn: conn, token: token, site: site} do
      url = Routes.plugins_api_shared_links_url(PlausibleWeb.Endpoint, :create)

      resp =
        conn
        |> authenticate(site.domain, token)
        |> put_req_header("content-type", "application/json")
        |> put(url, %{})
        |> json_response(422)
        |> assert_schema("UnprocessableEntityError", spec())

      assert %{errors: [%{detail: "Missing field: shared_link"}]} = resp
    end

    test "skips shared links feature access check", %{
      conn: conn,
      site: site,
      token: token
    } do
      insert(:starter_subscription, team: site.team)

      url = Routes.plugins_api_shared_links_url(PlausibleWeb.Endpoint, :create)

      resp =
        authenticate(conn, site.domain, token)
        |> put_req_header("content-type", "application/json")
        |> put(url, %{
          shared_link: %{
            name: "My Shared Link"
          }
        })
        |> json_response(201)
        |> assert_schema("SharedLink", spec())

      assert resp.shared_link.name == "My Shared Link"

      assert resp.shared_link.href =~
               "http://localhost:8000/share/#{URI.encode_www_form(site.domain)}?auth="
    end

    for special_name <- Plausible.Sites.shared_link_special_names() do
      test "can create shared link with the reserved '#{special_name}' name", %{
        conn: conn,
        site: site,
        token: token
      } do
        url = Routes.plugins_api_shared_links_url(PlausibleWeb.Endpoint, :create)

        resp =
          authenticate(conn, site.domain, token)
          |> put_req_header("content-type", "application/json")
          |> put(url, %{
            shared_link: %{
              name: unquote(special_name)
            }
          })
          |> json_response(201)
          |> assert_schema("SharedLink", spec())

        assert resp.shared_link.name == unquote(special_name)

        assert resp.shared_link.href =~
                 "http://localhost:8000/share/#{URI.encode_www_form(site.domain)}?auth="
      end
    end
  end

  describe "get /shared_links" do
    test "returns an empty shared link list if there's none", %{
      conn: conn,
      token: token,
      site: site
    } do
      url = Routes.plugins_api_shared_links_url(PlausibleWeb.Endpoint, :index)

      resp =
        conn
        |> authenticate(site.domain, token)
        |> get(url)
        |> json_response(200)
        |> assert_schema("SharedLink.ListResponse", spec())

      assert resp.shared_links == []
      assert resp.meta.pagination.has_next_page == false
      assert resp.meta.pagination.has_prev_page == false
      assert resp.meta.pagination.links == %{}
    end

    test "returns a shared links list with pagination", %{
      conn: conn,
      token: token,
      site: site
    } do
      for i <- 1..5 do
        insert(:shared_link, site: site, name: "Shared Link #{i}")
      end

      url =
        Routes.plugins_api_shared_links_url(PlausibleWeb.Endpoint, :index, limit: 2)

      initial_conn = authenticate(conn, site.domain, token)

      page1 =
        initial_conn
        |> get(url)
        |> json_response(200)
        |> assert_schema("SharedLink.ListResponse", spec())

      assert [%{shared_link: %{name: "Shared Link 5"}}, %{shared_link: %{name: "Shared Link 4"}}] =
               page1.shared_links

      assert page1.meta.pagination.has_next_page == true
      assert page1.meta.pagination.has_prev_page == false
      assert page1.meta.pagination.links.next
      refute page1.meta.pagination.links[:prev]

      page2 =
        initial_conn
        |> get(page1.meta.pagination.links.next.url)
        |> json_response(200)
        |> assert_schema("SharedLink.ListResponse", spec())

      assert [%{shared_link: %{name: "Shared Link 3"}}, %{shared_link: %{name: "Shared Link 2"}}] =
               page2.shared_links

      assert page2.meta.pagination.has_next_page == true
      assert page2.meta.pagination.has_prev_page == true
      assert page2.meta.pagination.links.next
      assert page2.meta.pagination.links.prev

      assert ^page1 =
               initial_conn
               |> get(page2.meta.pagination.links.prev.url)
               |> json_response(200)
               |> assert_schema("SharedLink.ListResponse", spec())
    end
  end
end
