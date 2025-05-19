defmodule PlausibleWeb.Live.CustomerSupport.TeamsTest do
  use PlausibleWeb.ConnCase, async: true
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
        assert text(html) =~ user.name
      end
    end
  end
end
