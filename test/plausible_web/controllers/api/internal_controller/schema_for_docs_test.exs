defmodule PlausibleWeb.Api.InternalController.SchemaForDocsTest do
  use PlausibleWeb.ConnCase, async: true
  use Plausible.Repo

  describe "GET /api/docs/query/schema.json" do
    test "returns json schema", %{conn: conn} do
      conn = get(conn, "/api/docs/query/schema.json")
      response = json_response(conn, 200)

      assert %{"$schema" => "http://json-schema.org/draft-07/schema#", "type" => "object"} =
               response
    end

    test "schema does not contain nodes with private comments", %{conn: conn} do
      conn = get(conn, "/api/docs/query/schema.json")
      refute response(conn, 200) =~ ~s/"$comment":"private"/
    end
  end
end
