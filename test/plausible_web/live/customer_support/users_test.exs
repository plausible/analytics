defmodule PlausibleWeb.Live.CustomerSupport.UsersTest do
  use PlausibleWeb.ConnCase, async: false
  use Plausible.Teams.Test
  use Plausible
  @moduletag :ee_only

  on_ee do
    import Phoenix.LiveViewTest
    import Plausible.Test.Support.HTML

    defp open_user(id) do
      Routes.customer_support_resource_path(
        PlausibleWeb.Endpoint,
        :details,
        :users,
        :user,
        id
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
  end
end
