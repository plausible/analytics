defmodule PlausibleWeb.Live.CustomerSupport.UsersTest do
  use PlausibleWeb.ConnCase, async: false
  use Plausible.Teams.Test
  use Plausible
  @moduletag :ee_only

  on_ee do
    import Phoenix.LiveViewTest
    import Plausible.Test.Support.HTML

    @endpoint PlausibleWeb.InternalEndpoint
    alias PlausibleWeb.InternalRouter.Helpers, as: InternalRoutes

    defp open_user(id, qs \\ []) do
      InternalRoutes.customer_support_resource_path(
        PlausibleWeb.InternalEndpoint,
        :details,
        :users,
        :user,
        id,
        qs
      )
    end

    describe "overview" do
      setup [:create_user, :log_in, :create_site]

      setup %{user: user} do
        patch_env(:super_admin_user_ids, [user.id])
      end

      test "renders", %{conn: conn, user: user} do
        {:ok, _lv, html} = live(conn, open_user(user.id))
        text = text(html)
        assert text =~ user.name
        assert text =~ user.email

        assert [uid] = find(html, "#user-identifier")
        assert text_of_attr(uid, "value") == "#{user.id}"

        team = team_of(user)
        assert [_] = find(html, ~s|a[href="/cs/teams/team/#{team.id}"]|)
      end

      test "404", %{conn: conn} do
        assert_raise Ecto.NoResultsError, fn ->
          {:ok, _lv, _html} = live(conn, open_user(9999))
        end
      end
    end

    describe "keys" do
      setup [:create_user, :log_in, :create_site]

      setup %{user: user} do
        patch_env(:super_admin_user_ids, [user.id])
      end

      test "renders", %{conn: conn, user: user} do
        k1 = insert(:api_key, user: user)
        k2 = insert(:api_key, user: user, team: team_of(user))
        k3 = insert(:api_key, user: new_user())

        {:ok, lv, html} = live(conn, open_user(user.id, tab: :keys))

        assert text(html) =~ "API Keys (2)"

        html = lv |> render() |> text()

        assert html =~ k1.key_prefix
        assert html =~ k2.key_prefix
        refute html =~ k3.key_prefix
      end
    end
  end
end
