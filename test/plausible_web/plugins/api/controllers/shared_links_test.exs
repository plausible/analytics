defmodule PlausibleWeb.Plugins.API.Controllers.SharedLinksTest do
  use PlausibleWeb.PluginsAPICase, async: true

  setup %{test: test} do
    site = insert(:site)
    {:ok, _token, raw_token} = Plausible.Plugins.API.Tokens.create(site, Atom.to_string(test))

    {:ok,
     %{
       site: site,
       token: raw_token
     }}
  end

  describe "unathorized calls" do
    for {method, url} <- [
          {:get, Routes.shared_links_url(base_uri(), :get, 1)},
          {:post, Routes.shared_links_url(base_uri(), :create)}
        ] do
      test "unauthorized call to #{url}", %{conn: conn} do
        conn
        |> unquote(method)(unquote(url))
        |> json_response(401)
        |> assert_schema("UnauthorizedError", spec())
      end
    end
  end

  describe "get /shared_links/:id" do
    test "validates input out of the box", %{conn: conn, token: token, site: site} do
      url = Routes.shared_links_url(base_uri(), :get, "hello")

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

      url = Routes.shared_links_url(base_uri(), :get, shared_link.id)

      resp =
        conn
        |> authenticate(site.domain, token)
        |> get(url)
        |> json_response(200)
        |> assert_schema("SharedLink", spec())

      assert resp.data.href ==
               "http://localhost:8000/share/#{site.domain}?auth=#{shared_link.slug}"

      assert resp.data.id == shared_link.id
      assert resp.data.password_protected == false
      assert resp.data.name == "Some Link Name"
    end

    test "fails to retrieve non-existing link", %{conn: conn, site: site, token: token} do
      url = Routes.shared_links_url(base_uri(), :get, 666)

      conn
      |> authenticate(site.domain, token)
      |> get(url)
      |> json_response(404)
      |> assert_schema("NotFoundError", spec())
    end

    test "fails to retrieve link from another site", %{conn: conn, site: site, token: token} do
      shared_link = insert(:shared_link, name: "Some Link Name", site: build(:site))
      url = Routes.shared_links_url(base_uri(), :get, shared_link.id)

      conn
      |> authenticate(site.domain, token)
      |> get(url)
      |> json_response(404)
      |> assert_schema("NotFoundError", spec())
    end
  end

  describe "post /shared_links" do
    test "successfully creates a shared link with the location header", %{
      conn: conn,
      site: site,
      token: token
    } do
      url = Routes.shared_links_url(base_uri(), :create)

      initial_conn = authenticate(conn, site.domain, token)

      conn =
        initial_conn
        |> put_req_header("content-type", "application/json")
        |> post(url, %{
          name: "My Shared Link"
        })

      resp =
        conn
        |> json_response(201)
        |> assert_schema("SharedLink", spec())

      assert resp.data.name == "My Shared Link"
      assert resp.data.href =~ "http://localhost:8000/share/#{site.domain}?auth="

      [location] = get_resp_header(conn, "location")

      assert location ==
               Routes.shared_links_url(base_uri(), :get, resp.data.id)

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
      url = Routes.shared_links_url(base_uri(), :create)

      initial_conn = authenticate(conn, site.domain, token)

      create = fn ->
        initial_conn
        |> put_req_header("content-type", "application/json")
        |> post(url, %{
          name: "My Shared Link"
        })
      end

      conn = create.()

      resp =
        conn
        |> json_response(201)
        |> assert_schema("SharedLink", spec())

      id = resp.data.id

      conn = create.()

      assert ^id =
               conn
               |> json_response(201)
               |> Map.fetch!("data")
               |> Map.fetch!("id")
    end

    test "validates input out of the box", %{conn: conn, token: token, site: site} do
      url = Routes.shared_links_url(base_uri(), :create)

      resp =
        conn
        |> authenticate(site.domain, token)
        |> put_req_header("content-type", "application/json")
        |> post(url, %{})
        |> json_response(422)
        |> assert_schema("UnprocessableEntityError", spec())

      assert %{errors: [%{detail: "Missing field: name"}]} = resp
    end
  end

  describe "get /shared_links" do
    test "returns an empty shared link list if there's none", %{
      conn: conn,
      token: token,
      site: site
    } do
      url = Routes.shared_links_url(base_uri(), :index)

      resp =
        conn
        |> authenticate(site.domain, token)
        |> get(url)
        |> json_response(200)
        |> assert_schema("SharedLink.ListResponse", spec())

      assert resp.data == []
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

      url = Routes.shared_links_url(base_uri(), :index, limit: 2)

      initial_conn = authenticate(conn, site.domain, token)

      page1 =
        initial_conn
        |> get(url)
        |> json_response(200)
        |> assert_schema("SharedLink.ListResponse", spec())

      assert [%{data: %{name: "Shared Link 5"}}, %{data: %{name: "Shared Link 4"}}] = page1.data
      assert page1.meta.pagination.has_next_page == true
      assert page1.meta.pagination.has_prev_page == false
      assert page1.meta.pagination.links.next
      refute page1.meta.pagination.links[:prev]

      page2 =
        initial_conn
        |> get(page1.meta.pagination.links.next.url)
        |> json_response(200)
        |> assert_schema("SharedLink.ListResponse", spec())

      assert [%{data: %{name: "Shared Link 3"}}, %{data: %{name: "Shared Link 2"}}] = page2.data

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
