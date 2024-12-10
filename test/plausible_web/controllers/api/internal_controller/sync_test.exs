defmodule PlausibleWeb.Api.InternalController.SyncTest do
  use PlausibleWeb.ConnCase, async: false
  use Plausible.Repo
  use Plausible.Teams.Test

  describe "PUT /api/:domain/disable-feature" do
    setup [:create_user, :log_in]

    @tag :ee_only
    test "when the logged-in user is an super-admin", %{conn: conn, user: user} do
      site = new_site()
      patch_env(:super_admin_user_ids, [user.id])

      conn = put(conn, "/api/#{site.domain}/disable-feature", %{"feature" => "conversions"})

      assert json_response(conn, 200) == "ok"
      assert %{conversions_enabled: false} = Plausible.Sites.get_by_domain(site.domain)
    end
  end
end
