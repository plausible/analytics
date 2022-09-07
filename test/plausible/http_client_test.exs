defmodule Plausible.HTTPClientTest do
  use ExUnit.Case, async: true

  alias Plausible.HTTPClient
  alias Plug.Conn

  setup do
    bypass = Bypass.open()
    {:ok, bypass: bypass}
  end

  test "get/2 works", %{bypass: bypass} do
    Bypass.expect_once(bypass, "GET", "/", fn conn ->
      Conn.resp(conn, 200, "ok")
    end)

    assert {:ok, %Finch.Response{status: 200, body: "ok"}} = HTTPClient.get(bypass_url(bypass))
  end

  test "post/3 works", %{bypass: bypass} do
    Bypass.expect_once(bypass, "POST", "/", fn conn ->
      Conn.resp(conn, 200, "ok")
    end)

    assert {:ok, %Finch.Response{status: 200, body: "ok"}} = HTTPClient.post(bypass_url(bypass))
  end

  test "post/3 doesn't alter params if binary passed",
       %{
         bypass: bypass
       } do
    body = "raw binary"
    headers = []

    Bypass.expect_once(bypass, "POST", "/", fn conn ->
      opts = Plug.Parsers.init(parsers: [:urlencoded, {:json, json_decoder: Jason}])

      conn
      |> Plug.Parsers.call(opts)
      |> Conn.resp(200, body)
    end)

    assert {:ok, %Finch.Response{status: 200, body: ^body}} =
             HTTPClient.post(bypass_url(bypass), headers, body)
  end

  test "post/3 URL-encodes params if request content-type is set to application/x-www-form-urlencoded and a map is supplied",
       %{
         bypass: bypass
       } do
    body = %{hello: :world, alice: :bob}
    headers = [{"Content-Type", "application/x-www-form-urlencoded"}]

    Bypass.expect_once(bypass, "POST", "/", fn conn ->
      opts = Plug.Parsers.init(parsers: [:urlencoded])
      conn = Plug.Parsers.call(conn, opts)

      assert hd(Conn.get_req_header(conn, "content-type")) == "application/x-www-form-urlencoded"
      assert conn.body_params["hello"] == "world"
      assert conn.body_params["alice"] == "bob"
      Conn.resp(conn, 200, "ok")
    end)

    assert {:ok, %Finch.Response{status: 200, body: "ok"}} =
             HTTPClient.post(bypass_url(bypass), headers, body)
  end

  test "post/3 JSON-encodes params if request content-type is other than application/x-www-form-urlencoded and a map is supplied",
       %{
         bypass: bypass
       } do
    params = %{hello: :world, alice: :bob}
    headers_no_content_type = [{"foo", "moo"}]
    headers_json = [{"Content-Type", "application/json"}]

    Bypass.expect_once(bypass, "POST", "/any", fn conn ->
      opts = Plug.Parsers.init(parsers: [:urlencoded, {:json, json_decoder: Jason}])
      conn = Plug.Parsers.call(conn, opts)

      assert Conn.get_req_header(conn, "content-type") == ["application/json"]
      assert conn.body_params["hello"] == "world"
      assert conn.body_params["alice"] == "bob"
      Conn.resp(conn, 200, "ok")
    end)

    Bypass.expect_once(bypass, "POST", "/json", fn conn ->
      opts = Plug.Parsers.init(parsers: [{:json, json_decoder: Jason}])
      conn = Plug.Parsers.call(conn, opts)

      assert Conn.get_req_header(conn, "content-type") == ["application/json"]
      assert conn.body_params["hello"] == "world"
      assert conn.body_params["alice"] == "bob"
      Conn.resp(conn, 200, "ok")
    end)

    assert {:ok, %Finch.Response{status: 200, body: "ok"}} =
             HTTPClient.post(bypass_url(bypass, path: "/json"), headers_json, params)

    assert {:ok, %Finch.Response{status: 200, body: "ok"}} =
             HTTPClient.post(bypass_url(bypass, path: "/any"), headers_no_content_type, params)
  end

  defp bypass_url(bypass, opts \\ []) do
    port = bypass.port
    path = Keyword.get(opts, :path, "/")

    "http://localhost:#{port}#{path}"
  end
end
