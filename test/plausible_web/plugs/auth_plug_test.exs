defmodule PlausibleWeb.AuthPlugTest do
  use Plausible.DataCase
  use Plug.Test
  alias PlausibleWeb.AuthPlug

  test "does nothing if user is not logged in" do
    conn =
      conn(:get, "/")
      |> init_test_session(%{})
      |> AuthPlug.call(%{})

    assert is_nil(conn.assigns[:current_user])
  end

  test "looks up current user if they are logged in" do
    user = insert(:user)
    subscription = insert(:subscription, user: user)

    conn =
      conn(:get, "/")
      |> init_test_session(%{current_user_id: user.id})
      |> AuthPlug.call(%{})

    assert conn.assigns[:current_user].id == user.id
    assert conn.assigns[:current_user].subscription.id == subscription.id
  end

  test "looks up the latest subscription" do
    user = insert(:user)

    _old_subscription =
      insert(:subscription, user: user, inserted_at: Timex.now() |> Timex.shift(days: -1))

    subscription = insert(:subscription, user: user, inserted_at: Timex.now())

    conn =
      conn(:get, "/")
      |> init_test_session(%{current_user_id: user.id})
      |> AuthPlug.call(%{})

    assert conn.assigns[:current_user].id == user.id
    assert conn.assigns[:current_user].subscription.id == subscription.id
  end
end
