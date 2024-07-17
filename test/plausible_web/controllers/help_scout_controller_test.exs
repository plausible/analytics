defmodule PlausibleWeb.HelpScoutControllerTest do
  use PlausibleWeb.ConnCase, async: true
  use Plausible

  @moduletag :ee_only

  on_ee do
    alias Plausible.HelpScout

    describe "callback/2" do
      test "returns details on success", %{conn: conn} do
        user = insert(:user)
        signature_key = Application.fetch_env!(:plausible, HelpScout)[:signature_key]
        data = ~s|{"customer-id":"500"}|

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

        conn = get(conn, "/helpscout/callback?customer-id=500&X-HelpScout-Signature=#{signature}")

        assert html_response(conn, 200) =~ "/crm/auth/user/#{user.id}"
      end

      test "returns error on failure", %{conn: conn} do
        conn = get(conn, "/helpscout/callback?customer-id=500&X-HelpScout-Signature=invalid")

        assert html_response(conn, 200) =~ "bad_signature"
      end
    end
  end
end
