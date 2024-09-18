defmodule PlausibleWeb.Api.InternalController.SchemaForDocsTest do
  use PlausibleWeb.ConnCase, async: true
  use Plausible.Repo

  describe "GET /api/docs/query/schema.json" do
    test "returns public schema in json format and it parses", %{conn: conn} do
      conn = get(conn, "/api/docs/query/schema.json")
      response = json_response(conn, 200)

      assert %{"$schema" => "http://json-schema.org/draft-07/schema#", "type" => "object"} =
               response
    end

    test "public schema does not contain any unexpected nodes", %{conn: conn} do
      conn = get(conn, "/api/docs/query/schema.json")
      refute response(conn, 200) =~ ~s/"$comment":"only :internal"/
      refute response(conn, 200) =~ ~s/"realtime"/
    end
  end
end
