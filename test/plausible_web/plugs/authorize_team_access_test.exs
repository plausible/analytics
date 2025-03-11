defmodule PlausibleWeb.Plugs.AuthorizeTeamAccessTest do
  use PlausibleWeb.ConnCase, async: true
  use Plausible.Teams.Test

  alias Plausible.Plugs.AuthorizeTeamAccess
  import Plug.Conn

  for role <- Plausible.Teams.Membership.roles() do
    test "passes when valid current role: #{role}" do
      conn =
        build_conn()
        |> assign(:current_role, unquote(role))
        |> AuthorizeTeamAccess.call()

      refute conn.halted
    end
  end

  for role <- Plausible.Teams.Membership.roles() do
    test "inits with role: #{role}" do
      assert AuthorizeTeamAccess.init([unquote(role)])
    end
  end

  test "fails to init with unknown role" do
    assert_raise MatchError, fn ->
      AuthorizeTeamAccess.init([:unknown_role])
    end
  end

  test "redirects to /sites on mismatch" do
    conn =
      build_conn()
      |> assign(:current_role, :admin)
      |> AuthorizeTeamAccess.call([:owner])

    assert conn.halted
    assert redirected_to(conn, 302) == "/sites"
  end
end
