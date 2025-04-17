defmodule PlausibleWeb.Live.GoalSettingsSyncTest do
  use PlausibleWeb.ConnCase, async: false
  use Plausible.Teams.Test

  import Phoenix.LiveViewTest

  describe "GoalSettings live view" do
    setup [:create_user, :log_in]

    @tag :ee_only
    test "lists goals for super admin", %{conn: conn, user: user} do
      patch_env(:super_admin_user_ids, [user.id])

      site = new_site()

      {:ok, g1} = Plausible.Goals.create(site, %{"page_path" => "/go/to/blog/**"})
      {:ok, g2} = Plausible.Goals.create(site, %{"event_name" => "Register"})
      {:ok, g3} = Plausible.Goals.create(site, %{"event_name" => "Purchase", "currency" => "EUR"})

      conn = assign(conn, :live_module, PlausibleWeb.Live.GoalSettings)
      assert {:ok, _lv, html} = live(conn, "/#{site.domain}/settings/goals")

      assert html =~ to_string(g1)
      assert html =~ to_string(g2)
      assert html =~ to_string(g3)
    end
  end
end
