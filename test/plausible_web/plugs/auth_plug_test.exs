defmodule PlausibleWeb.AuthPlugTest do
  use PlausibleWeb.ConnCase, async: true
  use Plausible.Teams.Test

  alias PlausibleWeb.AuthPlug

  setup [:create_user, :log_in]

  test "does nothing if user is not logged in" do
    conn =
      build_conn(:get, "/")
      |> init_test_session(%{})
      |> AuthPlug.call(%{})

    assert is_nil(conn.assigns[:current_user])
  end

  test "looks up current user if they are logged in", %{conn: conn, user: user} do
    subscribe_to_plan(user, "123", inserted_at: NaiveDateTime.utc_now())

    conn =
      conn
      |> Plug.Adapters.Test.Conn.conn(:get, "/", %{})
      |> AuthPlug.call(%{})

    assert conn.assigns[:current_user].id == user.id
    assert conn.assigns[:my_team].subscription.paddle_plan_id == "123"
  end

  test "looks up the latest subscription", %{conn: conn, user: user} do
    # old subscription
    subscribe_to_plan(
      user,
      "123",
      inserted_at: NaiveDateTime.shift(NaiveDateTime.utc_now(), day: -1)
    )

    subscribe_to_plan(
      user,
      "456",
      inserted_at: NaiveDateTime.utc_now()
    )

    conn =
      conn
      |> Plug.Adapters.Test.Conn.conn(:get, "/", %{})
      |> AuthPlug.call(%{})

    assert conn.assigns[:current_user].id == user.id
    assert conn.assigns[:my_team].subscription.paddle_plan_id == "456"
  end

  test "switches current team when `team` parameter provided", %{conn: conn, user: user} do
    subscribe_to_plan(user, "123", inserted_at: NaiveDateTime.utc_now())
    team = team_of(user)

    conn =
      conn
      |> Plug.Adapters.Test.Conn.conn(:get, "/", %{team: team.identifier})
      |> AuthPlug.call(%{})

    assert conn.assigns[:current_team].id == team.id
    assert get_session(conn, "current_team_id") == team.identifier
  end

  test "does not switch to team provided via `team` the user doesn't belong to", %{conn: conn} do
    other_user = new_user()
    subscribe_to_plan(other_user, "123", inserted_at: NaiveDateTime.utc_now())
    team = team_of(other_user)

    conn =
      conn
      |> Plug.Adapters.Test.Conn.conn(:get, "/", %{team: team.identifier})
      |> AuthPlug.call(%{})

    refute conn.assigns[:current_team]
    refute get_session(conn, "current_team_id")
  end

  test "does not switch to a team from session when the user doesn't belong to it", %{conn: conn} do
    other_user = new_user()
    subscribe_to_plan(other_user, "123", inserted_at: NaiveDateTime.utc_now())
    team = team_of(other_user)

    conn =
      conn
      |> put_session("current_team_id", team.identifier)
      |> Plug.Adapters.Test.Conn.conn(:get, "/", %{})
      |> AuthPlug.call(%{})

    refute conn.assigns[:current_team]
    refute get_session(conn, "current_team_id")
  end
end
