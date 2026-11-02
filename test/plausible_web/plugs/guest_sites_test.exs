defmodule PlausibleWeb.Plugs.GuestSitesTest do
  use PlausibleWeb.ConnCase, async: true

  import Plug.Conn

  alias PlausibleWeb.Plugs.GuestSites

  test "assigns false when the user isn't a guest of any site" do
    user = new_user()
    _own_site = new_site(owner: user)

    conn =
      build_conn()
      |> assign(:current_user, user)
      |> GuestSites.call(nil)

    assert conn.assigns.has_guest_sites? == false
  end

  test "assigns true when the user is a guest of a site" do
    user = new_user()
    add_guest(new_site(), user: user, role: :viewer)

    conn =
      build_conn()
      |> assign(:current_user, user)
      |> GuestSites.call(nil)

    assert conn.assigns.has_guest_sites? == true
  end
end
