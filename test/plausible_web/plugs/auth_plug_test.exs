defmodule PlausibleWeb.AuthPlugTest do
  use PlausibleWeb.ConnCase, async: true

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
    subscription = insert(:subscription, user: user, inserted_at: Timex.now())

    conn =
      conn
      |> Plug.Adapters.Test.Conn.conn(:get, "/", %{})
      |> AuthPlug.call(%{})

    assert conn.assigns[:current_user].id == user.id
    assert conn.assigns[:current_user].subscription.id == subscription.id
  end

  test "looks up the latest subscription", %{conn: conn, user: user} do
    _old_subscription =
      insert(:subscription, user: user, inserted_at: Timex.now() |> Timex.shift(days: -1))

    subscription = insert(:subscription, user: user, inserted_at: Timex.now())

    conn =
      conn
      |> Plug.Adapters.Test.Conn.conn(:get, "/", %{})
      |> AuthPlug.call(%{})

    assert conn.assigns[:current_user].id == user.id
    assert conn.assigns[:current_user].subscription.id == subscription.id
  end
end
