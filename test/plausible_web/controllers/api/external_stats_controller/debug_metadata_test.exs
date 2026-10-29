defmodule PlausibleWeb.Api.ExternalController.DebugMetadataTest do
  use PlausibleWeb.ConnCase

  describe "Debug metadata" do
    setup [:create_user, :create_api_key, :use_api_key]

    test "is saved correctly", %{conn: conn, user: user} do
      domain = :rand.bytes(20) |> Base.url_encode64()
      site = new_site(domain: domain, owner: user)

      query = %{
        "site_id" => site.domain,
        "date_range" => "all",
        "metrics" => ["visitors"]
      }

      conn =
        post(conn, "/api/v2/query", query)

      assert json_response(conn, 200)

      assert [r1, r2] =
               eventually(fn ->
                 rows = get_entries_from_query_log(site.domain)
                 {length(rows) == 2, rows}
               end)

      for [unparsed_log_comment] <- [r1, r2] do
        decoded = Jason.decode!(unparsed_log_comment)

        assert_matches ^strict_map(%{
                         # params are asserted below
                         "params" => %{},
                         "phoenix_action" => "query",
                         "phoenix_controller" =>
                           "Elixir.PlausibleWeb.Api.ExternalQueryApiController",
                         "request_method" => "POST",
                         "request_path" => "/api/v2/query",
                         "site_domain" => ^site.domain,
                         "site_id" => ^site.id,
                         "team_id" => ^team_of(user).id,
                         "trace_id" => _,
                         "user_id" => ^user.id
                       }) = decoded

        assert decoded["params"] == query
      end
    end
  end
end
