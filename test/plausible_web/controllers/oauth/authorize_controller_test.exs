defmodule PlausibleWeb.OAuth.AuthorizeControllerTest do
  @moduledoc """
  Tests /login/oauth/authorize screen
  """

  use PlausibleWeb.ConnCase
  use Plausible.Test.Support.DNS

  import Phoenix.LiveViewTest

  alias Plausible.OAuth.ProtectedResources
  alias Plausible.OAuth.Token

  @client_id "https://client.example.com/oauth-metadata"
  @redirect_uri "https://client.example.com/callback"

  setup %{conn: conn} do
    user = new_user()
    FunWithFlags.enable(:mcp, for_actor: user)
    {:ok, team} = Plausible.Teams.get_or_create(user)
    {:ok, conn: conn} = log_in(%{user: user, conn: conn})

    verifier = :crypto.strong_rand_bytes(32) |> Base.url_encode64(padding: false)
    challenge = :crypto.hash(:sha256, verifier) |> Base.url_encode64(padding: false)

    valid_params = %{
      "client_id" => @client_id,
      "redirect_uri" => @redirect_uri,
      "response_type" => "code",
      "code_challenge" => challenge,
      "code_challenge_method" => "S256",
      "scope" => "sites:read:*",
      "state" => "xyz-state",
      "resource" => ProtectedResources.get_resource_url(ProtectedResources.mcp())
    }

    valid_doc = %{
      "client_id" => @client_id,
      "redirect_uris" => [@redirect_uri],
      "client_name" => "Test Client"
    }

    {:ok, conn: conn, user: user, team: team, valid_params: valid_params, valid_doc: valid_doc}
  end

  test "returns 'not_implemented' when the :mcp flag is not enabled for the user", %{
    conn: conn,
    user: user,
    valid_params: valid_params
  } do
    # setup enables it for this user, so it needs disabling here
    FunWithFlags.disable(:mcp, for_actor: user)
    conn = get_authorize(conn, valid_params)
    assert %{"error" => "not_implemented"} == json_response(conn, 501)
  end

  test "redirects to login when unauthenticated, return_to is the expected shape", %{
    valid_params: valid_params
  } do
    conn = build_conn() |> get_authorize(valid_params)

    [base, qs] = String.split(redirected_to(conn), "?")

    assert base == "/login"
    assert_matches ^strict_map(%{"return_to" => return_to}) = URI.decode_query(qs)

    [authorize_path, authorize_qs] = String.split(return_to, "?")

    assert authorize_path == "/login/oauth/authorize"
    assert URI.decode_query(authorize_qs) == valid_params
  end

  test "renders an error page for an unreachable client_id", %{
    conn: conn,
    valid_params: valid_params
  } do
    stub_dns(%{"client.example.com" => {[], []}})

    assert conn |> get_authorize(valid_params) |> html_response(400) =~
             "Authorization error"
  end

  test "refuses an over-long client_name before rendering the consent screen",
       %{conn: conn, valid_params: valid_params, valid_doc: valid_doc} do
    stub_dns()

    stub_metadata(%{valid_doc | "client_name" => String.duplicate("N", 256)})

    assert conn |> get_authorize(valid_params) |> html_response(400) =~
             "Authorization error"
  end

  test "renders an error page for an unregistered redirect_uri", %{
    conn: conn,
    valid_params: valid_params,
    valid_doc: valid_doc
  } do
    stub_dns()
    stub_metadata(valid_doc)

    params =
      %{valid_params | "redirect_uri" => "https://evil.example.com/callback"}

    assert conn |> get_authorize(params) |> html_response(400) =~ "Authorization error"
  end

  test "redirects back with an error for an unsupported response_type", %{
    conn: conn,
    valid_params: valid_params,
    valid_doc: valid_doc
  } do
    stub_dns()
    stub_metadata(valid_doc)

    params = %{valid_params | "response_type" => "token"}

    conn = get_authorize(conn, params)

    location = redirected_to(conn, 302)
    [base, qs] = String.split(location, "?")

    assert base == valid_params["redirect_uri"]

    assert_matches ^strict_map(%{
                     "error" => "unsupported_response_type",
                     "state" => "xyz-state"
                   }) = URI.decode_query(qs)
  end

  test "redirects back with an error when PKCE is missing", %{
    conn: conn,
    valid_params: valid_params,
    valid_doc: valid_doc
  } do
    stub_dns()
    stub_metadata(valid_doc)

    params = %{valid_params | "code_challenge" => ""}

    conn = get_authorize(conn, params)

    location = redirected_to(conn, 302)
    [base, qs] = String.split(location, "?")

    assert base == valid_params["redirect_uri"]

    assert_matches ^strict_map(%{"error" => "invalid_request", "state" => "xyz-state"}) =
                     URI.decode_query(qs)
  end

  test "rejects the plain PKCE method", %{
    conn: conn,
    valid_params: valid_params,
    valid_doc: valid_doc
  } do
    stub_dns()
    stub_metadata(valid_doc)

    params = %{valid_params | "code_challenge_method" => "plain"}

    conn = get_authorize(conn, params)

    location = redirected_to(conn, 302)
    [base, qs] = String.split(location, "?")

    assert base == valid_params["redirect_uri"]

    assert_matches ^strict_map(%{"error" => "invalid_request", "state" => "xyz-state"}) =
                     URI.decode_query(qs)
  end

  test "redirects back with an error when resource is omitted", %{
    conn: conn,
    valid_params: valid_params,
    valid_doc: valid_doc
  } do
    stub_dns()
    stub_metadata(valid_doc)

    params = Map.delete(valid_params, "resource")

    conn = get_authorize(conn, params)

    location = redirected_to(conn, 302)
    [base, qs] = String.split(location, "?")

    assert base == valid_params["redirect_uri"]

    assert_matches ^strict_map(%{"error" => "invalid_target", "state" => "xyz-state"}) =
                     URI.decode_query(qs)
  end

  test "redirects back with an error when resource is blank", %{
    conn: conn,
    valid_params: valid_params,
    valid_doc: valid_doc
  } do
    stub_dns()
    stub_metadata(valid_doc)

    params = %{valid_params | "resource" => ""}

    conn = get_authorize(conn, params)

    location = redirected_to(conn, 302)
    [base, qs] = String.split(location, "?")

    assert base == valid_params["redirect_uri"]

    assert_matches ^strict_map(%{"error" => "invalid_target", "state" => "xyz-state"}) =
                     URI.decode_query(qs)
  end

  test "redirects back with invalid_target for an unknown resource", %{
    conn: conn,
    valid_params: valid_params,
    valid_doc: valid_doc
  } do
    stub_dns()
    stub_metadata(valid_doc)

    params = %{valid_params | "resource" => "https://elsewhere.example.com/mcp"}

    conn = get_authorize(conn, params)

    location = redirected_to(conn, 302)
    [base, qs] = String.split(location, "?")

    assert base == valid_params["redirect_uri"]

    assert_matches ^strict_map(%{"error" => "invalid_target", "state" => "xyz-state"}) =
                     URI.decode_query(qs)
  end

  test "redirects back with an error for an unsupported scope", %{
    conn: conn,
    valid_params: valid_params,
    valid_doc: valid_doc
  } do
    stub_dns()
    stub_metadata(valid_doc)

    params = %{valid_params | "scope" => "stats:read:* admin:write"}

    conn = get_authorize(conn, params)

    location = redirected_to(conn, 302)
    [base, qs] = String.split(location, "?")

    assert base == valid_params["redirect_uri"]

    assert_matches ^strict_map(%{"error" => "invalid_scope", "state" => "xyz-state"}) =
                     URI.decode_query(qs)
  end

  test "rate-limits the user, doesn't do a client metadata fetch when over limit", %{
    conn: conn,
    valid_params: valid_params,
    valid_doc: valid_doc
  } do
    stub_dns()

    fetches = stub_metadata(valid_doc)

    statuses = Enum.map(1..30, fn _ -> get_authorize(conn, valid_params).status end)

    # 30 requests fall into at most two one-minute windows of 10
    limits = Enum.count(statuses, &(&1 == 429))
    passes = Enum.count(statuses, &(&1 == 200))

    assert limits >= 10
    assert passes >= 10
    assert :atomics.get(fetches, 1) == passes
  end

  test "renders the consent screen with client and scope details", %{
    conn: conn,
    valid_params: valid_params,
    valid_doc: valid_doc
  } do
    stub_dns()
    stub_metadata(valid_doc)

    html = conn |> get_authorize(valid_params) |> html_response(200)

    assert html =~ "Authorize access"
    assert html =~ "Test Client"
    assert html =~ "Read the list and details of your sites"
  end

  test "shows the verified client_id alongside the document's chosen client_name",
       %{conn: conn, valid_params: valid_params, valid_doc: valid_doc} do
    stub_dns()
    stub_metadata(valid_doc)

    html = conn |> get_authorize(valid_params) |> html_response(200)
    identity = text_of_element(html, "[data-test-id=client-identity]")

    assert identity =~ "Test Client"
    assert identity =~ valid_params["client_id"]
  end

  test "shows the client_id when the document declares no client_name", %{
    conn: conn,
    valid_params: valid_params,
    valid_doc: valid_doc
  } do
    stub_dns()
    stub_metadata(Map.delete(valid_doc, "client_name"))

    html = conn |> get_authorize(valid_params) |> html_response(200)

    assert text_of_element(html, "[data-test-id=client-identity]") =~ valid_params["client_id"]
  end

  test "escapes the client_name it renders", %{
    conn: conn,
    valid_params: valid_params,
    valid_doc: valid_doc
  } do
    stub_dns()
    stub_metadata(%{valid_doc | "client_name" => "<script>alert('xss')</script>"})

    html = conn |> get_authorize(valid_params) |> html_response(200)

    refute html =~ "<script>alert"
    assert html =~ "&lt;script&gt;"
  end

  test "shows team name if user has one team", %{
    conn: conn,
    team: team,
    valid_params: valid_params,
    valid_doc: valid_doc
  } do
    stub_dns()
    stub_metadata(valid_doc)

    html = conn |> get_authorize(valid_params) |> html_response(200)

    assert html =~ team.name
    refute element_exists?(html, "select#team")
  end

  test "__team=... in the authorize URL does not switch team", %{
    conn: conn,
    user: user,
    valid_params: valid_params,
    valid_doc: valid_doc
  } do
    stub_dns()
    stub_metadata(valid_doc)

    other_owner = new_user()
    {:ok, other_team} = Plausible.Teams.get_or_create(other_owner)
    add_member(other_team, user: user, role: :editor)

    before = Plausible.Repo.reload!(user).last_team_identifier

    get_authorize(
      conn,
      Map.put(valid_params, "__team", other_team.identifier)
    )

    assert Plausible.Repo.reload!(user).last_team_identifier == before
  end

  test "approving the application redirects back with a code and the original state query param",
       %{
         conn: conn,
         user: user,
         team: team,
         valid_params: valid_params,
         valid_doc: valid_doc
       } do
    stub_dns()
    fetches = stub_metadata(valid_doc)

    lv = render_consent_screen(conn, valid_params)
    click(lv, "approve")
    {redirect_url, _flash} = assert_redirect(lv)

    # client metadata is fetched exactly once
    assert fetches |> :atomics.get(1) == 1

    [base, qs] = String.split(redirect_url, "?")
    decoded_qs = URI.decode_query(qs)

    assert base == valid_params["redirect_uri"]

    assert_matches ^strict_map(%{
                     "code" => ^any(:string, &(&1 != "")),
                     "state" => "xyz-state"
                   }) = decoded_qs

    assert_matches %{
                     code_hash: ^Token.hash(decoded_qs["code"]),
                     client_id: ^valid_params["client_id"],
                     client_name: ^valid_doc["client_name"],
                     redirect_uri: ^valid_params["redirect_uri"],
                     resource: ^valid_params["resource"],
                     code_challenge: ^valid_params["code_challenge"],
                     code_challenge_method: ^valid_params["code_challenge_method"],
                     scopes: [^valid_params["scope"]],
                     user_id: ^user.id,
                     team_id: ^team.id,
                     expires_at: ^(&(NaiveDateTime.compare(&1, NaiveDateTime.utc_now()) == :gt))
                   } = Plausible.Repo.one!(Plausible.OAuth.AuthorizationCode)
  end

  test "denying redirects back with access_denied and issues no code", %{
    conn: conn,
    valid_params: valid_params,
    valid_doc: valid_doc
  } do
    stub_dns()
    stub_metadata(valid_doc)

    lv = render_consent_screen(conn, valid_params)
    click(lv, "deny")
    {redirect_url, _flash} = assert_redirect(lv)

    [base, qs] = String.split(redirect_url, "?")

    assert base == valid_params["redirect_uri"]

    assert_matches ^strict_map(%{"error" => "access_denied", "state" => "xyz-state"}) =
                     URI.decode_query(qs)

    assert Plausible.Repo.aggregate(Plausible.OAuth.AuthorizationCode, :count) == 0
  end

  test "a user with an unverified email cannot reach the screen, let alone approve",
       %{conn: conn, user: user, valid_params: valid_params} do
    user |> Ecto.Changeset.change(email_verified: false) |> Plausible.Repo.update!()

    conn = get_authorize(conn, valid_params)

    assert redirected_to(conn) == "/activate"
    assert Plausible.Repo.aggregate(Plausible.OAuth.AuthorizationCode, :count) == 0
  end

  test "refuses an approval once the user is over the rate limit", %{
    conn: conn,
    user: user,
    valid_params: valid_params,
    valid_doc: valid_doc
  } do
    stub_dns()
    stub_metadata(valid_doc)

    lv = render_consent_screen(conn, valid_params)

    Enum.each(1..30, fn _ -> Plausible.Auth.rate_limit(:oauth_authorize_user, user) end)

    assert click(lv, "approve") =~ "Too many authorization requests"
    assert Plausible.Repo.aggregate(Plausible.OAuth.AuthorizationCode, :count) == 0
  end

  test "offers every team the user can grant, personal team included", %{
    conn: conn,
    team: team,
    user: user,
    valid_params: valid_params,
    valid_doc: valid_doc
  } do
    stub_dns()
    stub_metadata(valid_doc)

    {first, second} = grantable_teams(user)

    html = conn |> get_authorize(valid_params) |> html_response(200)
    options = text_of_element(html, "select#team")

    assert options =~ team.name
    assert options =~ first.name
    assert options =~ second.name
  end

  test "approving without touching the picker binds the team it preselected", %{
    conn: conn,
    team: team,
    user: user,
    valid_params: valid_params,
    valid_doc: valid_doc
  } do
    stub_dns()
    stub_metadata(valid_doc)

    grantable_teams(user)

    html = conn |> get_authorize(valid_params) |> html_response(200)
    assert text_of_element(html, "select#team option[selected]") == team.name

    lv = render_consent_screen(conn, valid_params)
    click(lv, "approve")
    {redirect_url, _flash} = assert_redirect(lv)

    [base, qs] = String.split(redirect_url, "?")

    assert base == valid_params["redirect_uri"]
    assert %{"code" => _} = URI.decode_query(qs)

    assert Plausible.Repo.one!(Plausible.OAuth.AuthorizationCode).team_id == team.id
  end

  test "binds the code to the selected team", %{
    conn: conn,
    user: user,
    valid_params: valid_params,
    valid_doc: valid_doc
  } do
    stub_dns()
    stub_metadata(valid_doc)

    {_first, second} = grantable_teams(user)
    params = Map.put(valid_params, "team", second.identifier)

    lv = render_consent_screen(conn, params)
    click(lv, "approve")
    {redirect_url, _flash} = assert_redirect(lv)

    [base, qs] = String.split(redirect_url, "?")

    assert base == valid_params["redirect_uri"]
    assert %{"code" => _} = URI.decode_query(qs)

    assert Plausible.Repo.one!(Plausible.OAuth.AuthorizationCode).team_id == second.id
  end

  test "ignores unknown team provided as param, binds to default instead", %{
    conn: conn,
    team: team,
    user: user,
    valid_params: valid_params,
    valid_doc: valid_doc
  } do
    stub_dns()
    stub_metadata(valid_doc)

    grantable_teams(user)
    other_team = insert(:team, identifier: Ecto.UUID.generate())
    params = Map.put(valid_params, "team", other_team.identifier)

    lv = render_consent_screen(conn, params)
    click(lv, "approve")
    {redirect_url, _flash} = assert_redirect(lv)

    [base, qs] = String.split(redirect_url, "?")

    assert base == valid_params["redirect_uri"]
    assert %{"code" => _} = URI.decode_query(qs)

    assert Plausible.Repo.one!(Plausible.OAuth.AuthorizationCode).team_id == team.id
  end

  defp grantable_teams(user) do
    first = insert(:team, name: "First Team", identifier: Ecto.UUID.generate())
    second = insert(:team, name: "Second Team", identifier: Ecto.UUID.generate())

    add_member(first, user: user, role: :owner)
    add_member(second, user: user, role: :owner)

    {first, second}
  end

  # Returns a counter of how many times the document was fetched.
  defp stub_metadata(doc) do
    counter = :atomics.new(1, [])

    Req.Test.stub(Plausible.OAuth.CIMD, fn conn ->
      :atomics.add_get(counter, 1, 1)
      Plug.Conn.send_resp(conn, 200, Jason.encode!(doc))
    end)

    counter
  end

  defp get_authorize(conn, params),
    do: get(conn, "/login/oauth/authorize?" <> URI.encode_query(params))

  # The screen is a LiveView embedded in a dead render, so `live/1` has no live
  # route to connect through. The controller still does the work: it is what
  # runs the request and builds the context, and the socket mounts with the very
  # ctx the dead render put on the page.
  defp render_consent_screen(conn, params) do
    rendered = get_authorize(conn, params)
    assert html_response(rendered, 200)

    {:ok, lv, _html} =
      live_isolated(conn, PlausibleWeb.Live.OAuthAuthorize,
        session: %{"ctx" => rendered.assigns.ctx}
      )

    lv
  end

  defp click(lv, action), do: lv |> element("button[phx-click=#{action}]") |> render_click()
end
