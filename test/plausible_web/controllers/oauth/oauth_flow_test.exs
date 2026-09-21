defmodule PlausibleWeb.OAuth.FlowTest do
  @moduledoc """
  Walks the full token acquire flow the way a real MCP client does: discovery ->
  consent -> authorization code -> access token.
  """

  use PlausibleWeb.ConnCase, async: true
  use Plausible.Test.Support.DNS

  @client_id "https://client.example.com/oauth-metadata"
  @redirect_uri "https://client.example.com/callback"

  setup %{conn: conn} do
    stub_dns()

    stub_metadata(%{
      "client_id" => @client_id,
      "redirect_uris" => [@redirect_uri],
      "client_name" => "Test Client"
    })

    user = new_user()
    {:ok, team} = Plausible.Teams.get_or_create(user)
    {:ok, conn: conn} = log_in(%{user: user, conn: conn})

    {:ok, conn: conn, user: user, team: team}
  end

  defp stub_metadata(doc) do
    Req.Test.stub(Plausible.OAuth.CIMD, fn conn ->
      Plug.Conn.send_resp(conn, 200, Jason.encode!(doc))
    end)
  end

  defp resource do
    alias Plausible.OAuth.ProtectedResources
    ProtectedResources.get_resource_url(ProtectedResources.mcp())
  end

  defp pkce do
    verifier = :crypto.strong_rand_bytes(32) |> Base.url_encode64(padding: false)
    challenge = :crypto.hash(:sha256, verifier) |> Base.url_encode64(padding: false)
    {verifier, challenge}
  end

  defp authorize_params(challenge, overrides \\ %{}) do
    Map.merge(
      %{
        "client_id" => @client_id,
        "redirect_uri" => @redirect_uri,
        "response_type" => "code",
        "code_challenge" => challenge,
        "code_challenge_method" => "S256",
        "scope" => "sites:read:*",
        "state" => "xyz-state",
        "resource" => resource()
      },
      overrides
    )
  end

  defp get_authorize(conn, params),
    do: get(conn, "/login/oauth/authorize?" <> URI.encode_query(params))

  defp approve(conn, params),
    do: post(conn, "/login/oauth/authorize", Map.put(params, "action", "approve"))

  defp params_from_redirect(conn) do
    location = redirected_to(conn, 302)
    assert String.starts_with?(location, @redirect_uri)
    location |> URI.parse() |> Map.fetch!(:query) |> URI.decode_query()
  end

  defp token_conn, do: build_conn() |> put_req_header("accept", "application/json")

  describe "GET /login/oauth/authorize" do
    test "renders the consent screen with client and scope details", %{conn: conn} do
      {_verifier, challenge} = pkce()

      html = conn |> get_authorize(authorize_params(challenge)) |> html_response(200)

      assert html =~ "Authorize access"
      assert html =~ "Test Client"
      assert html =~ "Read the list and details of your sites"
    end

    test "shows the verified client_id alongside the document's chosen client_name",
         %{conn: conn} do
      {_verifier, challenge} = pkce()

      html = conn |> get_authorize(authorize_params(challenge)) |> html_response(200)
      identity = text_of_element(html, "[data-test-id=client-identity]")

      assert identity =~ "Test Client"
      assert identity =~ @client_id
    end

    test "shows the client_id when the document declares no client_name", %{conn: conn} do
      stub_metadata(%{"client_id" => @client_id, "redirect_uris" => [@redirect_uri]})
      {_verifier, challenge} = pkce()

      html = conn |> get_authorize(authorize_params(challenge)) |> html_response(200)

      assert text_of_element(html, "[data-test-id=client-identity]") =~ @client_id
    end

    # Rendering it invites linking it, and nothing here validates its scheme.
    test "ignores a client_uri the document declares", %{conn: conn} do
      stub_metadata(%{
        "client_id" => @client_id,
        "redirect_uris" => [@redirect_uri],
        "client_name" => "Test Client",
        "client_uri" => "https://client-homepage.example.com"
      })

      {_verifier, challenge} = pkce()
      html = conn |> get_authorize(authorize_params(challenge)) |> html_response(200)

      assert html =~ "Test Client"
      refute html =~ "client-homepage.example.com"
    end

    test "escapes the client_name it renders", %{conn: conn} do
      {_verifier, challenge} = pkce()

      stub_metadata(%{
        "client_id" => @client_id,
        "redirect_uris" => [@redirect_uri],
        "client_name" => "<script>alert('xss')</script>"
      })

      html = conn |> get_authorize(authorize_params(challenge)) |> html_response(200)

      refute html =~ "<script>alert"
      assert html =~ "&lt;script&gt;"
    end

    test "offers no team selector when the user has no set-up team", %{conn: conn} do
      {_verifier, challenge} = pkce()

      html = conn |> get_authorize(authorize_params(challenge)) |> html_response(200)

      refute element_exists?(html, "select#team")
    end

    test "redirects to login when unauthenticated, preserving the request" do
      {_verifier, challenge} = pkce()

      conn = build_conn() |> get_authorize(authorize_params(challenge))

      location = redirected_to(conn)
      assert location =~ "/login"
      assert location =~ "return_to"
    end

    test "renders an error page for an unreachable client_id", %{conn: conn} do
      stub_dns(%{"client.example.com" => {[], []}})
      {_verifier, challenge} = pkce()

      assert conn |> get_authorize(authorize_params(challenge)) |> html_response(400) =~
               "Authorization error"
    end

    test "refuses an over-long client_name before rendering the consent screen",
         %{conn: conn} do
      stub_metadata(%{
        "client_id" => @client_id,
        "redirect_uris" => [@redirect_uri],
        "client_name" => String.duplicate("N", 256)
      })

      {_verifier, challenge} = pkce()

      assert conn |> get_authorize(authorize_params(challenge)) |> html_response(400) =~
               "Authorization error"
    end

    test "renders an error page for an unregistered redirect_uri", %{conn: conn} do
      {_verifier, challenge} = pkce()

      params =
        authorize_params(challenge, %{"redirect_uri" => "https://evil.example.com/callback"})

      assert conn |> get_authorize(params) |> html_response(400) =~ "Authorization error"
    end

    test "redirects back with an error for an unsupported response_type", %{conn: conn} do
      {_verifier, challenge} = pkce()
      params = authorize_params(challenge, %{"response_type" => "token"})

      returned = conn |> get_authorize(params) |> params_from_redirect()

      assert_matches ^strict_map(%{
                       "error" => "unsupported_response_type",
                       "state" => "xyz-state"
                     }) = returned
    end

    test "redirects back with an error when PKCE is missing", %{conn: conn} do
      params = authorize_params("", %{"code_challenge" => ""})

      assert conn |> get_authorize(params) |> params_from_redirect() |> Map.fetch!("error") ==
               "invalid_request"
    end

    test "rejects the plain PKCE method", %{conn: conn} do
      {_verifier, challenge} = pkce()
      params = authorize_params(challenge, %{"code_challenge_method" => "plain"})

      assert conn |> get_authorize(params) |> params_from_redirect() |> Map.fetch!("error") ==
               "invalid_request"
    end

    test "redirects back with an error when resource is omitted", %{conn: conn} do
      {_verifier, challenge} = pkce()
      params = challenge |> authorize_params() |> Map.delete("resource")

      assert conn |> get_authorize(params) |> params_from_redirect() |> Map.fetch!("error") ==
               "invalid_target"
    end

    test "redirects back with an error when resource is blank", %{conn: conn} do
      {_verifier, challenge} = pkce()
      params = authorize_params(challenge, %{"resource" => ""})

      assert conn |> get_authorize(params) |> params_from_redirect() |> Map.fetch!("error") ==
               "invalid_target"
    end

    test "redirects back with invalid_target for an unknown resource", %{conn: conn} do
      {_verifier, challenge} = pkce()
      params = authorize_params(challenge, %{"resource" => "https://elsewhere.example.com/mcp"})

      assert conn |> get_authorize(params) |> params_from_redirect() |> Map.fetch!("error") ==
               "invalid_target"
    end

    test "redirects back with an error for an unsupported scope", %{conn: conn} do
      {_verifier, challenge} = pkce()
      params = authorize_params(challenge, %{"scope" => "stats:read:* admin:write"})

      assert conn |> get_authorize(params) |> params_from_redirect() |> Map.fetch!("error") ==
               "invalid_scope"
    end
  end

  describe "POST /login/oauth/authorize" do
    test "approving redirects back with a code and the original state", %{conn: conn} do
      {_verifier, challenge} = pkce()

      returned = conn |> approve(authorize_params(challenge)) |> params_from_redirect()

      assert_matches ^strict_map(%{
                       "code" => ^any(:string, &(&1 != "")),
                       "state" => "xyz-state"
                     }) = returned
    end

    test "denying redirects back with access_denied and issues no code", %{conn: conn} do
      {_verifier, challenge} = pkce()
      params = Map.put(authorize_params(challenge), "action", "deny")

      returned = conn |> post("/login/oauth/authorize", params) |> params_from_redirect()

      assert_matches ^strict_map(%{"error" => "access_denied", "state" => "xyz-state"}) = returned

      assert Plausible.Repo.aggregate(Plausible.OAuth.AuthorizationCode, :count) == 0
    end

    test "a missing action is treated as a denial", %{conn: conn} do
      {_verifier, challenge} = pkce()

      returned =
        conn
        |> post("/login/oauth/authorize", authorize_params(challenge))
        |> params_from_redirect()

      assert returned["error"] == "access_denied"
    end
  end

  describe "team selection" do
    setup %{user: user} do
      first = insert(:team, name: "First Team", identifier: Ecto.UUID.generate())
      second = insert(:team, name: "Second Team", identifier: Ecto.UUID.generate())

      add_member(first, user: user, role: :owner)
      add_member(second, user: user, role: :owner)

      {:ok, first: first, second: second}
    end

    test "offers the user's set-up teams on the consent screen", %{
      conn: conn,
      first: first,
      second: second
    } do
      {_verifier, challenge} = pkce()

      html = conn |> get_authorize(authorize_params(challenge)) |> html_response(200)
      options = text_of_element(html, "select#team")

      assert options =~ first.name
      assert options =~ second.name
    end

    test "binds the code to the selected team", %{conn: conn, second: second} do
      {_verifier, challenge} = pkce()
      params = authorize_params(challenge, %{"team" => second.identifier})

      assert %{"code" => _} = conn |> approve(params) |> params_from_redirect()

      assert Plausible.Repo.one!(Plausible.OAuth.AuthorizationCode).team_id == second.id
    end

    test "falls back to the current team rather than binding one the user is not in", %{
      conn: conn
    } do
      {_verifier, challenge} = pkce()
      other_team = insert(:team, identifier: Ecto.UUID.generate())
      params = authorize_params(challenge, %{"team" => other_team.identifier})

      approved = approve(conn, params)
      assert %{"code" => _} = params_from_redirect(approved)

      assert Plausible.Repo.one!(Plausible.OAuth.AuthorizationCode).team_id ==
               approved.assigns.current_team.id
    end
  end

  describe "POST /login/oauth/token" do
    test "exchanges a code for an access token bound to the approving user", %{
      conn: conn,
      user: user,
      team: team
    } do
      {verifier, challenge} = pkce()
      %{"code" => code} = conn |> approve(authorize_params(challenge)) |> params_from_redirect()

      resp =
        token_conn()
        |> post("/login/oauth/token", %{
          "grant_type" => "authorization_code",
          "client_id" => @client_id,
          "code" => code,
          "code_verifier" => verifier,
          "redirect_uri" => @redirect_uri,
          "resource" => resource()
        })
        |> json_response(200)

      assert_matches ^strict_map(%{
                       "access_token" => ^any(:string),
                       "refresh_token" =>
                         ^any(
                           :string,
                           &String.starts_with?(
                             &1,
                             Plausible.OAuth.Token.plaintext_prefix(:refresh)
                           )
                         ),
                       "token_type" => "Bearer",
                       "expires_in" => ^Plausible.OAuth.access_token_ttl_seconds(),
                       "scope" => "sites:read:*"
                     }) = resp

      refute resp["refresh_token"] == resp["access_token"]

      assert {:ok, grant} =
               Plausible.OAuth.find_access_token(
                 resp["access_token"],
                 Plausible.OAuth.ProtectedResources.mcp()
               )

      assert_matches %{
                       user: %{id: ^user.id},
                       team: %{id: ^team.id},
                       resource: ^resource(),
                       refresh_token_hash: ^Plausible.OAuth.Token.hash(resp["refresh_token"]),
                       revoked_at: nil
                     } = grant
    end

    # Regression: authorize cast "" to nil while the token leg passed it through raw.
    test "rejects a blank resource rather than treating it as a mismatch", %{conn: conn} do
      {verifier, challenge} = pkce()
      %{"code" => code} = conn |> approve(authorize_params(challenge)) |> params_from_redirect()

      resp =
        token_conn()
        |> post("/login/oauth/token", %{
          "grant_type" => "authorization_code",
          "client_id" => @client_id,
          "code" => code,
          "code_verifier" => verifier,
          "redirect_uri" => @redirect_uri,
          "resource" => ""
        })
        |> json_response(400)

      assert resp["error"] == "invalid_request"
    end
  end
end
