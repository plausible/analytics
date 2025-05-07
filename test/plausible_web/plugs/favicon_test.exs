defmodule PlausibleWeb.FaviconTest do
  use Plausible.DataCase, async: true
  use Plug.Test
  alias PlausibleWeb.Favicon

  import Mox
  setup :verify_on_exit!

  setup_all do
    opts = PlausibleWeb.Favicon.init(nil)

    %{plug_opts: opts}
  end

  test "ignores request on a URL it does not need to handle", %{plug_opts: plug_opts} do
    old_conn = conn(:get, "/irrelevant")
    new_conn = Favicon.call(old_conn, plug_opts)

    refute new_conn.halted
    assert old_conn == new_conn
  end

  test "proxies request on favicon URL to duckduckgo", %{plug_opts: plug_opts} do
    expect(
      Plausible.HTTPClient.Mock,
      :get,
      fn "https://icons.duckduckgo.com/ip3/plausible.io.ico" ->
        {:ok, %Finch.Response{status: 200, body: "favicon response body"}}
      end
    )

    conn =
      conn(:get, "/favicon/sources/plausible.io")
      |> Favicon.call(plug_opts)

    assert conn.halted
    assert conn.status == 200
    assert conn.resp_body == "favicon response body"
  end

  test "requests favicon from DDG by hostname only (strips pathname)", %{plug_opts: plug_opts} do
    expect(
      Plausible.HTTPClient.Mock,
      :get,
      fn "https://icons.duckduckgo.com/ip3/site.com.ico" ->
        {:ok, %Finch.Response{status: 200, body: "favicon response body"}}
      end
    )

    conn =
      conn(:get, "/favicon/sources/site.com/subfolder")
      |> Favicon.call(plug_opts)

    assert conn.halted
    assert conn.status == 200
    assert conn.resp_body == "favicon response body"
  end

  test "sets content-disposition and content-security-policy", %{plug_opts: plug_opts} do
    expect(
      Plausible.HTTPClient.Mock,
      :get,
      fn "https://icons.duckduckgo.com/ip3/plausible.io.ico" ->
        {:ok, %Finch.Response{status: 200, body: "favicon response body"}}
      end
    )

    conn =
      conn(:get, "/favicon/sources/plausible.io")
      |> Favicon.call(plug_opts)

    assert conn.halted
    assert conn.status == 200
    assert conn.resp_body == "favicon response body"
    assert Plug.Conn.get_resp_header(conn, "content-security-policy") == ["script-src 'none'"]
    assert Plug.Conn.get_resp_header(conn, "content-disposition") == ["attachment"]
  end

  test "maps a categorized source to URL for favicon", %{plug_opts: plug_opts} do
    expect(
      Plausible.HTTPClient.Mock,
      :get,
      fn "https://icons.duckduckgo.com/ip3/facebook.com.ico" ->
        {:ok, %Finch.Response{status: 200, body: "favicon response body"}}
      end
    )

    conn =
      conn(:get, "/favicon/sources/Facebook")
      |> Favicon.call(plug_opts)

    assert conn.halted
    assert conn.status == 200
    assert conn.resp_body == "favicon response body"
  end

  test "copies content-type header from the proxied response", %{plug_opts: plug_opts} do
    expect(
      Plausible.HTTPClient.Mock,
      :get,
      fn "https://icons.duckduckgo.com/ip3/plausible.io.ico" ->
        {:ok,
         %Finch.Response{
           status: 200,
           body: "favicon response body",
           headers: [
             {"transfer-encoding", "chunked"},
             {"content-type", "should-pass-through"}
           ]
         }}
      end
    )

    conn =
      conn(:get, "/favicon/sources/plausible.io")
      |> Favicon.call(plug_opts)

    assert conn.halted
    assert conn.status == 200
    assert Plug.Conn.get_resp_header(conn, "content-type") == ["should-pass-through"]
  end

  test "overrides content-type header if proxied response starts with <svg", %{
    plug_opts: plug_opts
  } do
    expect(
      Plausible.HTTPClient.Mock,
      :get,
      fn "https://icons.duckduckgo.com/ip3/plausible.io.ico" ->
        {:ok,
         %Finch.Response{
           status: 200,
           body: "<svg>icon</svg>",
           headers: [{"content-type", "image/x-icon"}]
         }}
      end
    )

    conn =
      conn(:get, "/favicon/sources/plausible.io")
      |> Favicon.call(plug_opts)

    assert conn.halted
    assert Plug.Conn.get_resp_header(conn, "content-type") == ["image/svg+xml; charset=utf-8"]
  end

  describe "Fallback to placeholder icon" do
    @placeholder_icon File.read!("priv/placeholder_favicon.svg")

    test "falls back to placeholder when DDG returns a non-2xx response", %{plug_opts: plug_opts} do
      expect(
        Plausible.HTTPClient.Mock,
        :get,
        fn "https://icons.duckduckgo.com/ip3/plausible.io.ico" ->
          res = %Finch.Response{status: 503, body: "bad gateway"}
          {:error, Plausible.HTTPClient.Non200Error.new(res)}
        end
      )

      conn =
        conn(:get, "/favicon/sources/plausible.io")
        |> Favicon.call(plug_opts)

      assert conn.halted
      assert conn.status == 200
      assert conn.resp_body == @placeholder_icon
    end

    test "falls back to placeholder in case of a network error", %{plug_opts: plug_opts} do
      expect(
        Plausible.HTTPClient.Mock,
        :get,
        fn "https://icons.duckduckgo.com/ip3/plausible.io.ico" ->
          {:error, %Mint.TransportError{reason: :closed}}
        end
      )

      conn =
        conn(:get, "/favicon/sources/plausible.io")
        |> Favicon.call(plug_opts)

      assert conn.halted
      assert conn.status == 200
      assert conn.resp_body == @placeholder_icon
    end

    test "falls back to placeholder when DDG returns a broken image response", %{
      plug_opts: plug_opts
    } do
      expect(
        Plausible.HTTPClient.Mock,
        :get,
        fn "https://icons.duckduckgo.com/ip3/plausible.io.ico" ->
          {:ok, %Finch.Response{status: 200, body: <<137, 80, 78, 71, 13, 10, 26, 10>>}}
        end
      )

      conn =
        conn(:get, "/favicon/sources/plausible.io")
        |> Favicon.call(plug_opts)

      assert conn.halted
      assert conn.status == 200
      assert conn.resp_body == @placeholder_icon
    end
  end
end
