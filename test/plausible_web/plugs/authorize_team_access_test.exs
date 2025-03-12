defmodule PlausibleWeb.Plugs.AuthorizeTeamAccessTest do
  use PlausibleWeb.ConnCase, async: true
  use Plausible.Teams.Test

  alias Plausible.Plugs.AuthorizeTeamAccess
  import Plug.Conn

  for role <- Plausible.Teams.Membership.roles() -- [:guest] do
    test "passes when valid current role: #{role}" do
      conn =
        build_conn()
        |> assign(:current_team_role, unquote(role))
        |> AuthorizeTeamAccess.call()

      refute conn.halted
    end
  end

  for role <- Plausible.Teams.Membership.roles() -- [:guest] do
    test "inits with role: #{role}" do
      assert AuthorizeTeamAccess.init([unquote(role)])
    end
  end

  test "fails to init with invalid role" do
    assert_raise MatchError, fn ->
      AuthorizeTeamAccess.init([:guest])
    end

    assert_raise MatchError, fn ->
      AuthorizeTeamAccess.init([:unknown])
    end
  end

  test "redirects to /sites on mismatch" do
    conn =
      build_conn()
      |> assign(:current_team, :some)
      |> assign(:current_team_role, :admin)
      |> AuthorizeTeamAccess.call([:owner])

    assert conn.halted
    assert redirected_to(conn, 302) == "/sites"
  end

  test "is permissive when no :current_team assigned" do
    conn =
      build_conn()
      |> assign(:current_team, nil)
      |> assign(:current_team_role, :admin)
      |> AuthorizeTeamAccess.call([:owner])

    refute conn.halted
  end
end
