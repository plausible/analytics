defmodule PlausibleWeb.Plugins.API.ErrorsTest do
  use ExUnit.Case, async: true

  import Phoenix.ConnTest, only: [json_response: 2]

  alias PlausibleWeb.Plugins.API.Errors

  describe "unauthorized/1" do
    test "sends an 401 response with the `www-authenticate` header set" do
      conn =
        Plug.Test.conn(:get, "/")
        |> Errors.unauthorized()

      assert conn.halted

      assert json_response(conn, 401) == %{
               "errors" => [%{"detail" => "Plugins API: unauthorized"}]
             }

      assert Plug.Conn.get_resp_header(conn, "www-authenticate") == [
               ~s[Basic realm="Plugins API Access"]
             ]
    end
  end

  describe "error/3" do
    test "formats the given error message" do
      message = "Some message"

      conn =
        Plug.Test.conn(:get, "/")
        |> Errors.error(:forbidden, message)

      assert conn.halted

      assert json_response(conn, 403) == %{
               "errors" => [%{"detail" => "Some message"}]
             }
    end
  end
end
