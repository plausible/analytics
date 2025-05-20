defmodule PlausibleWeb.Live.CustomerSupport.TeamsTest do
  use PlausibleWeb.ConnCase, async: false
  use Plausible.Teams.Test
  use Plausible
  @moduletag :ee_only

  on_ee do
    import Phoenix.LiveViewTest
    import Plausible.Test.Support.HTML

    defp open_team(id) do
      Routes.customer_support_resource_path(
        PlausibleWeb.Endpoint,
        :details,
        :teams,
        :team,
        id
      )
    end

    describe "overview" do
      setup [:create_user, :log_in, :create_site]

      setup %{user: user} do
        patch_env(:super_admin_user_ids, [user.id])
      end

      test "renders", %{conn: conn, user: user} do
        team = team_of(user)
        {:ok, _lv, html} = live(conn, open_team(team.id))
        assert text(html) =~ team.name
      end
    end
  end
end
