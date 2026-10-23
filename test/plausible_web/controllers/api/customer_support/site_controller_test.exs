defmodule PlausibleWeb.Api.CustomerSupport.SiteControllerTest do
  use PlausibleWeb.ConnCase, async: false
  use Plausible
  use Plausible.Repo

  on_ee do
    use Bamboo.Test, shared: true

    @approval %{"conversation" => "1", "code" => "ABCD", "approved_by" => "marko"}

    setup %{conn: conn} do
      automation = new_user()
      patch_env(:cs_automation_user_ids, [automation.id])
      api_key = insert(:api_key, user: automation, scopes: ["cs:sites:*"])
      conn = put_req_header(conn, "authorization", "Bearer #{api_key.key}")

      owner = new_user()
      site = new_site(owner: owner, domain: "shop.example.com")

      {:ok, conn: conn, owner: owner, site: site}
    end

    describe "ingest rate limit" do
      test "sets the threshold and scale", %{conn: conn, site: site} do
        conn =
          post(conn, "/api/cs/v1/sites/#{site.id}/ingest_rate_limit", %{
            approval: @approval,
            domain: site.domain,
            ingest_rate_limit_threshold: 20_000,
            ingest_rate_limit_scale_seconds: 60
          })

        assert json_response(conn, 200)["result"]["ingest_rate_limit_threshold"] == 20_000
        site = Repo.reload!(site)
        assert site.ingest_rate_limit_threshold == 20_000
        assert site.ingest_rate_limit_scale_seconds == 60
        assert Repo.get_by(Plausible.Audit.Entry, name: "cs_api_site_rate_limit_updated")
      end

      test "null removes the limit", %{conn: conn, site: site} do
        site
        |> Ecto.Changeset.change(ingest_rate_limit_threshold: 10_000)
        |> Repo.update!()

        conn =
          post(conn, "/api/cs/v1/sites/#{site.id}/ingest_rate_limit", %{
            approval: @approval,
            domain: site.domain,
            ingest_rate_limit_threshold: nil,
            ingest_rate_limit_scale_seconds: 60
          })

        assert json_response(conn, 200)
        assert is_nil(Repo.reload!(site).ingest_rate_limit_threshold)
      end

      test "refuses a wrong domain", %{conn: conn, site: site} do
        conn =
          post(conn, "/api/cs/v1/sites/#{site.id}/ingest_rate_limit", %{
            approval: @approval,
            domain: "other.example.com",
            ingest_rate_limit_threshold: 0,
            ingest_rate_limit_scale_seconds: 60
          })

        assert json_response(conn, 422)["error"] =~ "domain"
        refute Repo.reload!(site).ingest_rate_limit_threshold == 0
      end

      test "refuses a negative threshold", %{conn: conn, site: site} do
        conn =
          post(conn, "/api/cs/v1/sites/#{site.id}/ingest_rate_limit", %{
            approval: @approval,
            domain: site.domain,
            ingest_rate_limit_threshold: -1,
            ingest_rate_limit_scale_seconds: 60
          })

        assert json_response(conn, 422)
      end
    end

    test "sets the native stats start", %{conn: conn, site: site} do
      conn =
        post(conn, "/api/cs/v1/sites/#{site.id}/native_stats_start", %{
          approval: @approval,
          domain: site.domain,
          native_stats_start_at: "2024-03-01T00:00:00"
        })

      assert json_response(conn, 200)
      assert Repo.reload!(site).native_stats_start_at == ~N[2024-03-01 00:00:00]
    end

    describe "transfer" do
      test "sends the ownership transfer email", %{conn: conn, owner: owner, site: site} do
        conn =
          post(conn, "/api/cs/v1/sites/#{site.id}/transfer", %{
            approval: @approval,
            domain: site.domain,
            inviter_email: owner.email,
            invitee_email: "new-owner@example.com"
          })

        assert json_response(conn, 200)["result"]["invitee_email"] == "new-owner@example.com"

        assert_email_delivered_with(
          to: [nil: "new-owner@example.com"],
          subject: ~r/Request to transfer ownership of #{site.domain}/
        )
      end

      test "refuses an inviter who isn't on the site's team", %{conn: conn, site: site} do
        stranger = new_user()

        conn =
          post(conn, "/api/cs/v1/sites/#{site.id}/transfer", %{
            approval: @approval,
            domain: site.domain,
            inviter_email: stranger.email,
            invitee_email: "new-owner@example.com"
          })

        assert json_response(conn, 422)["error"] =~ "permission_denied"
      end
    end

    test "needs the cs:sites scope", %{site: site} do
      automation = new_user()
      patch_env(:cs_automation_user_ids, [automation.id])
      api_key = insert(:api_key, user: automation, scopes: ["cs:billing:*"])

      conn =
        build_conn()
        |> put_req_header("authorization", "Bearer #{api_key.key}")
        |> post("/api/cs/v1/sites/#{site.id}/ingest_rate_limit", %{
          approval: @approval,
          domain: site.domain,
          ingest_rate_limit_threshold: 0,
          ingest_rate_limit_scale_seconds: 60
        })

      assert json_response(conn, 401)
    end
  end
end
