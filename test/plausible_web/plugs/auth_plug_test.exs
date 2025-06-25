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
    assert conn.assigns[:current_team_role] == :owner
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
      |> Plug.Adapters.Test.Conn.conn(:get, "/", %{__team: team.identifier})
      |> AuthPlug.call(%{})

    assert conn.assigns[:current_team].id == team.id
    assert conn.assigns[:current_team_role] == :owner
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

  test "falls back to my_team when there's no current team picked", %{conn: conn, user: user} do
    subscribe_to_plan(user, "123", inserted_at: NaiveDateTime.utc_now())
    team = team_of(user)

    conn =
      conn
      |> Plug.Adapters.Test.Conn.conn(:get, "/", %{})
      |> AuthPlug.call(%{})

    assert conn.assigns[:current_team].id == team.id
    refute get_session(conn, "current_team_id")
  end

  test "tracks current team role", %{conn: conn, user: user} do
    other_user = new_user()
    subscribe_to_plan(other_user, "123", inserted_at: NaiveDateTime.utc_now())
    team = team_of(other_user)

    add_member(team, user: user, role: :editor)
    conn = set_current_team(conn, team)

    conn =
      conn
      |> Plug.Adapters.Test.Conn.conn(:get, "/", %{})
      |> AuthPlug.call(%{})

    assert conn.assigns[:current_team].id == team.id
    assert conn.assigns[:current_team_role] == :editor
  end

  test "stores team identifier when team changes", %{conn: conn, user: user} do
    subscribe_to_plan(user, "123", inserted_at: NaiveDateTime.utc_now())
    team = team_of(user)

    assert is_nil(user.last_team_identifier)

    conn =
      conn
      |> Plug.Adapters.Test.Conn.conn(:get, "/", %{__team: team.identifier})
      |> AuthPlug.call(%{})

    updated_user = Plausible.Repo.reload!(user)
    assert updated_user.last_team_identifier == team.identifier
    assert get_session(conn, "current_team_id") == team.identifier
  end

  test "clears team identifier when recently stored team identifier doesn't exist", %{
    conn: conn,
    user: user
  } do
    subscribe_to_plan(user, "123", inserted_at: NaiveDateTime.utc_now())

    stale_team_id = Ecto.UUID.generate()
    :ok = Plausible.Users.remember_last_team(user, stale_team_id)
    assert Plausible.Repo.reload!(user).last_team_identifier

    conn =
      conn
      |> put_session("current_team_id", stale_team_id)
      |> Plug.Adapters.Test.Conn.conn(:get, "/", %{})
      |> AuthPlug.call(%{})

    updated_user = Plausible.Repo.reload!(user)
    assert is_nil(updated_user.last_team_identifier)
    refute get_session(conn, "current_team_id")
  end

  test "assigns expired session for further subsequent processing", %{conn: conn} do
    now = NaiveDateTime.utc_now(:second)
    in_the_past = NaiveDateTime.add(now, -1, :hour)
    {:ok, user_session} = PlausibleWeb.UserAuth.get_user_session(conn)
    user_session |> Ecto.Changeset.change(timeout_at: in_the_past) |> Plausible.Repo.update!()

    conn =
      conn
      |> Plug.Adapters.Test.Conn.conn(:get, "/", %{})
      |> AuthPlug.call(%{})

    refute conn.assigns[:current_user]
    refute conn.assigns[:current_team]
    assert conn.assigns[:expired_session].id == user_session.id
  end
end
