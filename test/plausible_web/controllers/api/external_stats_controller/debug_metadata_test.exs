defmodule PlausibleWeb.Api.ExternalController.DebugMetadataTest do
  alias Plausible.{IngestRepo, ClickhouseRepo}
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
        post(conn, "api/v2/query", query)

      assert json_response(conn, 200)

      IngestRepo.query!("SYSTEM FLUSH LOGS")

      %{rows: [r1, r2]} =
        ClickhouseRepo.query!(
          "FROM system.query_log SELECT log_comment WHERE JSONExtractString(log_comment, 'site_domain') = {$0:String}",
          [site.domain]
        )

      for [unparsed_log_comment] <- [r1, r2] do
        decoded = Jason.decode!(unparsed_log_comment)

        assert_matches ^strict_map(%{
                         # params are asserted below
                         "params" => %{},
                         "phoenix_action" => "query",
                         "phoenix_controller" =>
                           "Elixir.PlausibleWeb.Api.ExternalQueryApiController",
                         "request_method" => "POST",
                         "request_path" => "api/v2/query",
                         "site_domain" => ^site.domain,
                         "site_id" => ^site.id,
                         "team_id" => ^team_of(user).id,
                         "user_id" => ^user.id
                       }) = decoded

        assert decoded["params"] == query
      end
    end
  end
end
