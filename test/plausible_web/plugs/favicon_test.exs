defmodule PlausibleWeb.FaviconTest do
  use Plausible.DataCase
  use Plug.Test
  alias PlausibleWeb.Favicon

  import Mox
  setup :verify_on_exit!

  setup_all do
    opts = PlausibleWeb.Favicon.init(nil)

    %{plug_opts: opts}
  end

  test "ignores request on a URL it does not need to handle", %{plug_opts: plug_opts} do
    conn =
      conn(:get, "/irrelevant")
      |> Favicon.call(plug_opts)

    refute conn.halted
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
end
