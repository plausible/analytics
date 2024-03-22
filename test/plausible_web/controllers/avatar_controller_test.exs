defmodule PlausibleWeb.AvatarControllerTest do
  use PlausibleWeb.ConnCase, async: true

  import Mox
  setup :verify_on_exit!

  setup {PlausibleWeb.FirstLaunchPlug.Test, :skip}

  describe "GET /avatar/:hash" do
    test "proxies the request to gravatar", %{conn: conn} do
      expect(
        Plausible.HTTPClient.Mock,
        :get,
        fn "https://www.gravatar.com/avatar/myhash?s=150&d=identicon" ->
          {:ok,
           %Finch.Response{
             status: 200,
             body: "avatar response body",
             headers: [
               {"content-type", "image/png"},
               {"cache-control", "max-age=300"},
               {"expires", "soon"}
             ]
           }}
        end
      )

      conn = get(conn, "/avatar/myhash")

      assert response(conn, 200) =~ "avatar response body"
      assert {"content-type", "image/png"} in conn.resp_headers
      assert {"cache-control", "max-age=300"} in conn.resp_headers
      assert {"expires", "soon"} in conn.resp_headers
    end
  end
end
