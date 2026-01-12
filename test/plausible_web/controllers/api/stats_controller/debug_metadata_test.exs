defmodule PlausibleWeb.Api.StatsController.DebugMetadataTest do
  alias Plausible.{IngestRepo, ClickhouseRepo}
  use PlausibleWeb.ConnCase

  describe "Debug metadata for logged in requests" do
    setup [:create_user, :log_in]

    test "for main-graph", %{conn: conn, user: user} do
      domain = :rand.bytes(20) |> Base.url_encode64()
      site = new_site(domain: domain, owner: user)
      conn = get(conn, "/api/stats/#{site.domain}/main-graph")

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
                         "params" => ^strict_map(%{"domain" => ^site.domain}),
                         "phoenix_action" => "main_graph",
                         "phoenix_controller" => "Elixir.PlausibleWeb.Api.StatsController",
                         "request_method" => "GET",
                         "request_path" => ^"/api/stats/#{site.domain}/main-graph",
                         "site_domain" => ^site.domain,
                         "site_id" => ^site.id,
                         "team_id" => ^team_of(user).id,
                         "user_id" => ^user.id
                       }) = decoded
      end
    end
  end

  defp setup_dashboard_case(domain, type) do
    site_owner = new_user()

    case type do
      "public" ->
        site = new_site(domain: domain, owner: site_owner, public: true)
        {site, "", %{"domain" => domain}}

      "shared" ->
        site = new_site(domain: domain, owner: site_owner)
        link = insert(:shared_link, site: site)

        {site, "?auth=#{link.slug}", %{"domain" => domain, "auth" => link.slug}}
    end
  end

  describe "Debug metadata for non-private dashboard requests" do
    setup [:create_user, :log_in]

    for type <- ["public", "shared"] do
      test "for /pages request (#{type})", %{
        conn: conn,
        user: user
      } do
        domain = :rand.bytes(20) |> Base.url_encode64()
        {site, query_string, expected_params} = setup_dashboard_case(domain, unquote(type))
        conn = get(conn, "/api/stats/#{site.domain}/pages#{query_string}")

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
                           "phoenix_action" => "pages",
                           "phoenix_controller" => "Elixir.PlausibleWeb.Api.StatsController",
                           "request_method" => "GET",
                           "request_path" => ^"/api/stats/#{site.domain}/pages",
                           "site_domain" => ^site.domain,
                           "site_id" => ^site.id,
                           # nil team_id because viewing a public/shared dashboard
                           "team_id" => nil,
                           # the logged in user ID is included even when viewing a random public dashboard
                           "user_id" => ^user.id
                         }) = decoded

          assert decoded["params"] == expected_params
        end
      end
    end
  end
end
