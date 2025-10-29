defmodule PlausibleWeb.Live.SharedLinkSettingsTest do
  use PlausibleWeb.ConnCase, async: true
  use Plausible.Teams.Test
  import Phoenix.LiveViewTest
  import Plausible.Test.Support.HTML

  describe "SharedLinkSettings LiveView" do
    setup [:create_user, :log_in, :create_site]

    setup %{user: user, site: site} do
      subscribe_to_growth_plan(user)
      {:ok, session: %{"site_id" => site.id, "domain" => site.domain}}
    end

    test "allows shared link deletion", %{conn: conn, site: site, session: session} do
      link1 = insert(:shared_link, site: site, name: "Link 1")
      link2 = insert(:shared_link, site: site, name: "Link 2")

      lv = get_liveview(conn, session)
      html = render(lv)

      assert html =~ "Link 1"
      assert html =~ "Link 2"

      html =
        lv
        |> element(~s/button[phx-click="delete-shared-link"][phx-value-slug="#{link1.slug}"]/)
        |> render_click()

      refute html =~ "Link 1"
      assert html =~ "Link 2"
      assert html =~ "Shared link deleted"

      # Verify it's actually deleted from database
      refute Plausible.Repo.get_by(Plausible.Site.SharedLink, slug: link1.slug)
      assert Plausible.Repo.get_by(Plausible.Site.SharedLink, slug: link2.slug)
    end

    test "shows success message when link is deleted", %{conn: conn, site: site, session: session} do
      link = insert(:shared_link, site: site, name: "Test Link")

      lv = get_liveview(conn, session)

      html =
        lv
        |> element(~s/button[phx-click="delete-shared-link"][phx-value-slug="#{link.slug}"]/)
        |> render_click()

      assert html =~ "Shared link deleted"
      refute html =~ "Test Link"
    end

    test "shows error message when trying to delete non-existent link (race condition)", %{
      conn: conn,
      site: site,
      session: session
    } do
      # Simulate race condition: link exists when page loads, but is deleted
      # by another user/process before we click delete
      link = insert(:shared_link, site: site, name: "Test Link")

      lv = get_liveview(conn, session)

      html = render(lv)
      assert html =~ "Test Link"

      Plausible.Repo.delete!(link)

      html =
        lv
        |> element(~s/button[phx-click="delete-shared-link"][phx-value-slug="#{link.slug}"]/)
        |> render_click()

      assert html =~ "Could not find Shared Link"
    end

    test "displays shared links with password indicators", %{
      conn: conn,
      site: site,
      session: session
    } do
      _link_with_password =
        insert(:shared_link, site: site, name: "Protected", password: "secret")

      _link_without_password = insert(:shared_link, site: site, name: "Public")

      lv = get_liveview(conn, session)
      html = render(lv)

      assert html =~ "Protected"
      assert html =~ "Public"
      # Check for lock icons
      assert element_exists?(html, ~s|svg|)
    end

    test "displays empty state when no shared links", %{conn: conn, session: session} do
      lv = get_liveview(conn, session)
      html = render(lv)

      assert html =~ "No shared links configured for this site"
    end
  end

  defp get_liveview(conn, session) do
    {:ok, lv, _html} = live_isolated(conn, PlausibleWeb.Live.SharedLinkSettings, session: session)
    lv
  end
end
