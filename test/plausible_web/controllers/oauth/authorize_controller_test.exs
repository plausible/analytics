defmodule PlausibleWeb.OAuth.AuthorizeControllerTest do
  @moduledoc """
  Tests /login/oauth/authorize screen
  """

  use PlausibleWeb.ConnCase, async: true
  use Plausible.Test.Support.DNS

  import Phoenix.LiveViewTest

  @client_id "https://client.example.com/oauth-metadata"
  @redirect_uri "https://client.example.com/callback"

  @metadata_doc %{
    "client_id" => @client_id,
    "redirect_uris" => [@redirect_uri],
    "client_name" => "Test Client"
  }

  setup %{conn: conn} do
    stub_dns()

    stub_metadata(@metadata_doc)

    user = new_user()
    FunWithFlags.enable(:mcp, for_actor: user)
    {:ok, team} = Plausible.Teams.get_or_create(user)
    {:ok, conn: conn} = log_in(%{user: user, conn: conn})

    {:ok, conn: conn, user: user, team: team}
  end

  describe "GET /login/oauth/authorize" do
    test "returns 'not_implemented' when the :mcp flag is not enabled for the user", %{
      conn: conn,
      user: user
    } do
      # setup enables it for this user, so it needs disabling here
      FunWithFlags.disable(:mcp, for_actor: user)

      {_verifier, challenge} = pkce()
      conn = get_authorize(conn, authorize_params(challenge))

      assert %{"error" => "not_implemented"} == json_response(conn, 501)
    end

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

    test "shows team name if user has one team", %{conn: conn, team: team} do
      {_verifier, challenge} = pkce()

      html = conn |> get_authorize(authorize_params(challenge)) |> html_response(200)

      assert html =~ team.name
      refute element_exists?(html, "select#team")
    end

    test "__team=... in the authorize URL does not switch team", %{
      conn: conn,
      user: user
    } do
      other_owner = new_user()
      {:ok, other_team} = Plausible.Teams.get_or_create(other_owner)
      add_member(other_team, user: user, role: :editor)

      {_verifier, challenge} = pkce()
      before = Plausible.Repo.reload!(user).last_team_identifier

      get_authorize(
        conn,
        Map.put(authorize_params(challenge), "__team", other_team.identifier)
      )

      assert Plausible.Repo.reload!(user).last_team_identifier == before
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

    test "rate-limits the user, doesn't do a client metadata fetch when over limit", %{conn: conn} do
      fetches = stub_metadata_with_counter(@metadata_doc)
      {_verifier, challenge} = pkce()
      params = authorize_params(challenge)

      statuses = Enum.map(1..30, fn _ -> get_authorize(conn, params).status end)

      # 30 requests fall into at most two one-minute windows of 10
      limits = Enum.count(statuses, &(&1 == 429))
      passes = Enum.count(statuses, &(&1 == 200))

      assert limits >= 10
      assert passes >= 10
      assert :atomics.get(fetches, 1) == passes
    end
  end

  describe "the consent decision" do
    test "approving redirects back with a code and the original state", %{conn: conn} do
      {_verifier, challenge} = pkce()

      returned = conn |> approve(authorize_params(challenge)) |> params_from_redirect()

      assert_matches ^strict_map(%{
                       "code" => ^any(:string, &(&1 != "")),
                       "state" => "xyz-state"
                     }) = returned
    end

    test "the client_name stored on the code is the one the user was shown", %{conn: conn} do
      {_verifier, challenge} = pkce()
      params = authorize_params(challenge)

      stub_metadata(%{
        "client_id" => @client_id,
        "redirect_uris" => [@redirect_uri],
        "client_name" => "Shown Name"
      })

      assert conn |> get_authorize(params) |> html_response(200) =~ "Shown Name"

      lv = consent_screen(conn, params)
      assert render(lv) =~ "Shown Name"

      fetches =
        stub_metadata_with_counter(%{
          "client_id" => @client_id,
          "redirect_uris" => [@redirect_uri],
          "client_name" => "Swapped After Approval"
        })

      click(lv, "approve")

      assert Plausible.Repo.one!(Plausible.OAuth.AuthorizationCode).client_name == "Shown Name"

      # Nothing is re-read once the screen exists, so there is no second
      # response for a swapped document to arrive in.
      assert :atomics.get(fetches, 1) == 0
    end

    test "denying redirects back with access_denied and issues no code", %{conn: conn} do
      {_verifier, challenge} = pkce()

      returned = conn |> deny(authorize_params(challenge)) |> params_from_redirect()

      assert_matches ^strict_map(%{"error" => "access_denied", "state" => "xyz-state"}) = returned

      assert Plausible.Repo.aggregate(Plausible.OAuth.AuthorizationCode, :count) == 0
    end

    test "a user with an unverified email cannot reach the screen, let alone approve",
         %{conn: conn, user: user} do
      user |> Ecto.Changeset.change(email_verified: false) |> Plausible.Repo.update!()

      {_verifier, challenge} = pkce()
      conn = get_authorize(conn, authorize_params(challenge))

      assert redirected_to(conn) == "/activate"
      assert Plausible.Repo.aggregate(Plausible.OAuth.AuthorizationCode, :count) == 0
    end

    test "refuses an approval once the user is over the rate limit", %{conn: conn, user: user} do
      {_verifier, challenge} = pkce()
      lv = consent_screen(conn, authorize_params(challenge))

      Enum.each(1..30, fn _ -> Plausible.Auth.rate_limit(:oauth_authorize_user, user) end)

      assert click(lv, "approve") =~ "Too many authorization requests"
      assert Plausible.Repo.aggregate(Plausible.OAuth.AuthorizationCode, :count) == 0
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

    test "offers every team the user can grant, personal team included", %{
      conn: conn,
      team: team,
      first: first,
      second: second
    } do
      {_verifier, challenge} = pkce()

      html = conn |> get_authorize(authorize_params(challenge)) |> html_response(200)
      options = text_of_element(html, "select#team")

      assert options =~ team.name
      assert options =~ first.name
      assert options =~ second.name
    end

    test "approving without touching the picker binds the team it preselected", %{
      conn: conn,
      team: team
    } do
      {_verifier, challenge} = pkce()
      params = authorize_params(challenge)

      html = conn |> get_authorize(params) |> html_response(200)
      assert text_of_element(html, "select#team option[selected]") == team.name

      assert %{"code" => _} = conn |> approve(params) |> params_from_redirect()

      assert Plausible.Repo.one!(Plausible.OAuth.AuthorizationCode).team_id == team.id
    end

    test "binds the code to the selected team", %{conn: conn, second: second} do
      {_verifier, challenge} = pkce()
      params = authorize_params(challenge, %{"team" => second.identifier})

      assert %{"code" => _} = conn |> approve(params) |> params_from_redirect()

      assert Plausible.Repo.one!(Plausible.OAuth.AuthorizationCode).team_id == second.id
    end

    test "ignores unknown team provided as param, binds to default instead", %{
      conn: conn,
      team: team
    } do
      {_verifier, challenge} = pkce()
      other_team = insert(:team, identifier: Ecto.UUID.generate())
      params = authorize_params(challenge, %{"team" => other_team.identifier})

      assert %{"code" => _} = conn |> approve(params) |> params_from_redirect()

      assert Plausible.Repo.one!(Plausible.OAuth.AuthorizationCode).team_id == team.id
    end
  end

  defp stub_metadata(doc) do
    Req.Test.stub(Plausible.OAuth.CIMD, fn conn ->
      Plug.Conn.send_resp(conn, 200, Jason.encode!(doc))
    end)
  end

  defp stub_metadata_with_counter(doc) do
    counter = :atomics.new(1, [])

    Req.Test.stub(Plausible.OAuth.CIMD, fn conn ->
      :atomics.add_get(counter, 1, 1)
      Plug.Conn.send_resp(conn, 200, Jason.encode!(doc))
    end)

    counter
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

  # The screen is a LiveView embedded in a dead render, so it is reached the way
  # the rest of the suite reaches those: isolated, given the context the
  # controller would have built. `build/1` is the single fetch a round trip makes.
  defp consent_screen(conn, params) do
    {:ok, ctx} = PlausibleWeb.OAuth.AuthorizationRequest.build(params)

    {:ok, lv, _html} =
      live_isolated(conn, PlausibleWeb.Live.OAuthAuthorize, session: %{"ctx" => ctx})

    lv
  end

  defp approve(conn, params), do: conn |> consent_screen(params) |> click("approve")

  defp deny(conn, params), do: conn |> consent_screen(params) |> click("deny")

  defp click(lv, action), do: lv |> element("button[phx-click=#{action}]") |> render_click()

  defp params_from_redirect({:error, {:redirect, %{to: url}}}), do: params_from_redirect(url)

  defp params_from_redirect(%Plug.Conn{} = conn),
    do: params_from_redirect(redirected_to(conn, 302))

  defp params_from_redirect(url) when is_binary(url) do
    assert String.starts_with?(url, @redirect_uri)
    url |> URI.parse() |> Map.fetch!(:query) |> URI.decode_query()
  end
end
