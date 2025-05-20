defmodule PlausibleWeb.Live.CustomerSupport.SitesTest do
  use PlausibleWeb.ConnCase, async: false
  use Plausible.Teams.Test
  use Plausible
  @moduletag :ee_only

  on_ee do
    import Phoenix.LiveViewTest
    import Plausible.Test.Support.HTML

    defp open_site(id) do
      Routes.customer_support_resource_path(
        PlausibleWeb.Endpoint,
        :details,
        :sites,
        :site,
        id
      )
    end

    describe "overview" do
      setup [:create_user, :log_in, :create_site]

      setup %{user: user} do
        patch_env(:super_admin_user_ids, [user.id])
      end

      test "renders", %{conn: conn, site: site} do
        {:ok, _lv, html} = live(conn, open_site(site.id))
        assert text(html) =~ site.domain
      end
    end
  end
end
