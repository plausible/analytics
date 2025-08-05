defmodule PlausibleWeb.HelpScoutControllerTest do
  use PlausibleWeb.ConnCase, async: true
  use Plausible

  @moduletag :ee_only

  on_ee do
    import Plausible.Teams.Test

    alias Plausible.HelpScout

    describe "callback/2" do
      test "returns details on success", %{conn: conn} do
        user = insert(:user)
        signature_key = Application.fetch_env!(:plausible, HelpScout)[:signature_key]
        data = ~s|{"conversation-id":"123","customer-id":"500"}|

        signature =
          :hmac
          |> :crypto.mac(:sha, signature_key, data)
          |> Base.encode64()
          |> URI.encode_www_form()

        Req.Test.stub(HelpScout, fn
          %{request_path: "/v2/oauth2/token"} = conn ->
            Req.Test.json(conn, %{
              "token_type" => "bearer",
              "access_token" => "369dbb08be58430086d2f8bd832bc1eb",
              "expires_in" => 172_800
            })

          %{request_path: "/v2/customers/500"} = conn ->
            Req.Test.json(conn, %{
              "id" => 500,
              "_embedded" => %{
                "emails" => [
                  %{
                    "id" => 1,
                    "value" => user.email,
                    "type" => "home"
                  }
                ]
              }
            })
        end)

        conn =
          get(
            conn,
            "/helpscout/callback?conversation-id=123&customer-id=500&X-HelpScout-Signature=#{signature}"
          )

        assert html_response(conn, 200) =~
                 Routes.customer_support_user_path(PlausibleWeb.Endpoint, :show, user.id)
      end

      test "returns error on failure", %{conn: conn} do
        conn =
          get(
            conn,
            "/helpscout/callback?conversation-id=123&customer-id=500&X-HelpScout-Signature=invalid"
          )

        assert html_response(conn, 200) =~ "bad_signature"
      end

      test "handles invalid parameters gracefully", %{conn: conn} do
        conn =
          get(
            conn,
            "/helpscout/callback?customer-id=500&X-HelpScout-Signature=whatever"
          )

        assert html_response(conn, 200) =~ "Missing expected parameters"
      end
    end

    describe "search/2" do
      test "returns results", %{conn: conn} do
        insert(:user, email: "hs.match@plausible.test")
        insert(:user, email: "hs.nomatch@plausible.test")

        token = sign_conversation_token("123")

        conn =
          conn
          |> get(
            "/helpscout/search?conversation_id=123&customer_id=500&term=hs.match&token=#{token}"
          )

        html = html_response(conn, 200)

        assert html =~ "hs.match@plausible.test"
        refute html =~ "hs.nomatch@plausible.test"
      end

      test "returns error when token is invalid", %{conn: conn} do
        conn =
          get(
            conn,
            "/helpscout/search?conversation_id=123&customer_id=500&term=hs.match&token=invalid"
          )

        assert html_response(conn, 200) =~ "invalid_token"
      end

      test "returns error when token does not match", %{conn: conn} do
        token = sign_conversation_token("456")

        conn =
          conn
          |> get(
            "/helpscout/search?conversation_id=123&customer_id=500&term=hs.match&token=#{token}"
          )

        assert html_response(conn, 200) =~ "invalid_conversation"
      end
    end

    describe "show/2" do
      test "returns details on success", %{conn: conn} do
        user = insert(:user, email: "hs.match@plausible.test", notes: "Some note\nwith new line")

        token = sign_conversation_token("123")

        conn =
          conn
          |> get(
            "/helpscout/show?conversation_id=123&customer_id=500&email=hs.match@plausible.test&token=#{token}"
          )

        assert html = html_response(conn, 200)
        assert html =~ Routes.customer_support_user_path(PlausibleWeb.Endpoint, :show, user.id)
        assert html =~ "Some note<br>\nwith new line"
      end

      test "returns teams list when the match is an owner in multiple teams", %{conn: conn} do
        user = new_user(email: "hs.match@plausible.test", notes: "Some user notes")
        other_user = new_user()
        _site1 = new_site(owner: user)
        _site2 = new_site(owner: other_user)
        _team1 = team_of(user)
        team2 = team_of(other_user)

        team2 =
          team2
          |> Plausible.Teams.complete_setup()
          |> Ecto.Changeset.change(name: "HS Integration Test Team")
          |> Plausible.Repo.update!()

        add_member(team2, user: user, role: :owner)

        token = sign_conversation_token("123")

        conn =
          conn
          |> get(
            "/helpscout/show?conversation_id=123&customer_id=500&email=hs.match@plausible.test&token=#{token}"
          )

        assert html = html_response(conn, 200)
        assert html =~ Routes.customer_support_user_path(PlausibleWeb.Endpoint, :show, user.id)
        assert html =~ "Some user notes"
        assert html =~ "My Personal Sites"
        assert html =~ "HS Integration Test Team"
      end

      test "returns personal team details when identifier passed explicitly", %{conn: conn} do
        user = new_user(email: "hs.match@plausible.test", notes: "Some user notes")
        other_user = new_user()
        _site1 = new_site(owner: user)
        _site2 = new_site(owner: other_user)
        team1 = team_of(user)
        team2 = team_of(other_user)

        team2 =
          team2
          |> Plausible.Teams.complete_setup()
          |> Ecto.Changeset.change(name: "HS Integration Test Team")
          |> Plausible.Repo.update!()

        add_member(team2, user: user, role: :owner)

        token = sign_conversation_token("123")

        conn =
          conn
          |> get(
            "/helpscout/show?conversation_id=123&customer_id=500&email=hs.match@plausible.test&team_identifier=#{team1.identifier}&token=#{token}"
          )

        assert html = html_response(conn, 200)
        refute html =~ "HS Integration Test Team"
        refute html =~ "My Personal Sites"
        assert html =~ "Some user notes"
      end

      test "returns setup team details when identifier passed explicitly", %{conn: conn} do
        user = new_user(email: "hs.match@plausible.test", notes: "Some user notes")
        other_user = new_user()
        _site1 = new_site(owner: user)
        _site2 = new_site(owner: other_user)
        _team1 = team_of(user)
        team2 = team_of(other_user)

        team2 =
          team2
          |> Plausible.Teams.complete_setup()
          |> Ecto.Changeset.change(name: "HS Integration Test Team")
          |> Plausible.Repo.update!()

        add_member(team2, user: user, role: :owner)

        token = sign_conversation_token("123")

        conn =
          conn
          |> get(
            "/helpscout/show?conversation_id=123&customer_id=500&email=hs.match@plausible.test&team_identifier=#{team2.identifier}&token=#{token}"
          )

        assert html = html_response(conn, 200)
        assert html =~ "HS Integration Test Team"
        refute html =~ "My Personal Sites"
        assert html =~ "Some user notes"
      end

      test "returns error when token is invalid", %{conn: conn} do
        conn =
          get(
            conn,
            "/helpscout/show?conversation_id=123&customer_id=500&email=hs.match@plausible.test&token=invalid"
          )

        assert html_response(conn, 200) =~ "invalid_token"
      end

      test "returns error when token does not match", %{conn: conn} do
        token = sign_conversation_token("456")

        conn =
          conn
          |> get(
            "/helpscout/show?conversation_id=123&customer_id=500&email=hs.match@plausible.test&token=#{token}"
          )

        assert html_response(conn, 200) =~ "invalid_conversation"
      end
    end

    defp sign_conversation_token(conversation_id) do
      PlausibleWeb.HelpScoutController.sign_token(conversation_id)
    end
  end
end
