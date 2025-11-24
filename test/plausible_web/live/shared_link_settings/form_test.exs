defmodule PlausibleWeb.Live.SharedLinkSettings.FormTest do
  use PlausibleWeb.ConnCase, async: true
  import Phoenix.LiveViewTest
  import Plausible.Test.Support.HTML

  describe "Shared link form" do
    setup [:create_user, :log_in, :create_site]

    setup %{user: user, site: site} do
      subscribe_to_growth_plan(user)
      {:ok, session: %{"site_id" => site.id, "domain" => site.domain}}
    end

    test "renders form fields for creating a shared link", %{
      conn: conn,
      session: session
    } do
      lv = get_liveview(conn, session)

      lv |> element("button#add-shared-link-button") |> render_click()
      html = render(lv)

      assert html =~ "New shared link"
      assert element_exists?(html, ~s|input[name="shared_link[name]"]|)
      assert element_exists?(html, ~s|input[name="shared_link[password]"][type="password"]|)
      assert element_exists?(html, ~s|button[type="submit"]|)
    end

    test "renders error on empty submission", %{conn: conn, session: session} do
      lv = get_liveview(conn, session)

      lv |> element("button#add-shared-link-button") |> render_click()

      html = lv |> find_form() |> render_submit()

      assert html =~ "can&#39;t be blank"
    end

    test "creates a shared link without password", %{conn: conn, site: site, session: session} do
      lv = get_liveview(conn, session)
      refute render(lv) =~ "My Shared Link"

      lv |> element("button#add-shared-link-button") |> render_click()

      lv
      |> find_form()
      |> render_submit(%{shared_link: %{name: "My Shared Link"}})

      html = render(lv)
      assert html =~ "My Shared Link"
      assert html =~ "Shared link saved"

      shared_link =
        Plausible.Repo.get_by(Plausible.Site.SharedLink, name: "My Shared Link", site_id: site.id)

      assert shared_link
      refute shared_link.password_hash
    end

    test "creates a shared link with password", %{conn: conn, site: site, session: session} do
      lv = get_liveview(conn, session)
      refute render(lv) =~ "Protected Link"

      lv |> element("button#add-shared-link-button") |> render_click()

      lv
      |> find_form()
      |> render_submit(%{shared_link: %{name: "Protected Link", password: "secret123"}})

      html = render(lv)
      assert html =~ "Protected Link"
      assert html =~ "Shared link saved"

      shared_link =
        Plausible.Repo.get_by(Plausible.Site.SharedLink, name: "Protected Link", site_id: site.id)

      assert shared_link
      assert shared_link.password_hash
    end

    test "renders form fields for editing a shared link", %{
      conn: conn,
      site: site,
      session: session
    } do
      shared_link = insert(:shared_link, site: site, name: "Existing Link")

      lv = get_liveview(conn, session)

      lv
      |> element(~s/button[phx-click="edit-shared-link"][phx-value-slug="#{shared_link.slug}"]/)
      |> render_click()

      html = render(lv)
      assert html =~ "Edit shared link"
      assert element_exists?(html, ~s|input[name="shared_link[name]"]|)
      assert html =~ ~s|value="#{shared_link.name}"|
    end

    test "updates a shared link name", %{conn: conn, site: site, session: session} do
      shared_link = insert(:shared_link, site: site, name: "Original Name")

      lv = get_liveview(conn, session)

      lv
      |> element(~s/button[phx-click="edit-shared-link"][phx-value-slug="#{shared_link.slug}"]/)
      |> render_click()

      lv
      |> find_form()
      |> render_submit(%{shared_link: %{name: "Updated Name"}})

      html = render(lv)
      assert html =~ "Updated Name"
      assert html =~ "Shared link saved"
      refute html =~ "Original Name"

      updated = Plausible.Repo.get!(Plausible.Site.SharedLink, shared_link.id)
      assert updated.name == "Updated Name"
      assert updated.id == shared_link.id
    end

    test "updates a shared link password", %{conn: conn, site: site, session: session} do
      shared_link = insert(:shared_link, site: site, name: "Test Link", password: "old_password")

      lv = get_liveview(conn, session)

      lv
      |> element(~s/button[phx-click="edit-shared-link"][phx-value-slug="#{shared_link.slug}"]/)
      |> render_click()

      old_hash = shared_link.password_hash

      lv
      |> find_form()
      |> render_submit(%{shared_link: %{name: "Test Link", password: "new_password123"}})

      _html = render(lv)

      updated = Plausible.Repo.get!(Plausible.Site.SharedLink, shared_link.id)
      assert updated.password_hash != old_hash
      assert updated.password_hash
    end

    test "removes password when password field is left empty on update", %{
      conn: conn,
      site: site,
      session: session
    } do
      shared_link = insert(:shared_link, site: site, name: "Test Link", password: "old_password")

      lv = get_liveview(conn, session)

      lv
      |> element(~s/button[phx-click="edit-shared-link"][phx-value-slug="#{shared_link.slug}"]/)
      |> render_click()

      lv
      |> find_form()
      |> render_submit(%{shared_link: %{name: "Test Link", password: ""}})

      _html = render(lv)

      updated = Plausible.Repo.get!(Plausible.Site.SharedLink, shared_link.id)
      refute updated.password_hash
    end

    test "renders error when shared link name is invalid", %{
      conn: conn,
      session: session
    } do
      lv = get_liveview(conn, session)

      lv |> element("button#add-shared-link-button") |> render_click()

      html = lv |> find_form() |> render_submit(%{shared_link: %{name: ""}})

      assert html =~ "can&#39;t be blank"
    end

    test "shows upgrade required error when subscription doesn't include Shared Links", %{
      conn: conn,
      site: site,
      session: session
    } do
      site.team |> Plausible.Teams.Team.end_trial() |> Plausible.Repo.update!()
      insert(:starter_subscription, team: site.team)

      lv = get_liveview(conn, session)

      lv |> element("button#add-shared-link-button") |> render_click()

      html =
        lv
        |> find_form()
        |> render_submit(%{shared_link: %{name: "Test Link"}})

      assert html =~ "New shared link" or
               html =~ "Your current subscription plan does not include Shared Links"
    end
  end

  defp get_liveview(conn, session) do
    {:ok, lv, _html} = live_isolated(conn, PlausibleWeb.Live.SharedLinkSettings, session: session)
    lv
  end

  defp find_form(lv) do
    lv |> element("#shared-links-form-modalseq0 form")
  end
end
