defmodule PlausibleWeb.Live.SharedLinkSettings.FormTest do
  use PlausibleWeb.ConnCase, async: true
  import Phoenix.LiveViewTest

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
      assert html =~ "Password protect"
      assert html =~ "Limit to segment"
      assert element_exists?(html, ~s|button[role="switch"]#password-protect-|)
      assert element_exists?(html, ~s|button[role="switch"]#limit-view-|)
      assert element_exists?(html, ~s|input[name="shared_link[name]"]|)
      assert element_exists?(html, ~s|input[name="shared_link[password]"][type="password"]|)
      assert element_exists?(html, ~s|input[name="shared_link[segment_id]"]|)
      assert element_exists?(html, ~s|button[type="submit"]|)

      assert element_exists?(
               html,
               ~s|a[href="https://plausible.io/docs/filters-segments#how-to-save-a-segment"]|
             )
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

    test "creates a shared link limited to segment", %{conn: conn, site: site, session: session} do
      segment = insert(:segment, type: :site, site: site, name: "Scandinavia")
      lv = get_liveview(conn, session)

      lv |> element("button#add-shared-link-button") |> render_click()

      lv
      |> find_form()
      |> render_submit(%{shared_link: %{name: "Limited to Scandinavia", segment_id: segment.id}})

      html = render(lv)
      assert html =~ "Limited to Scandinavia"
      assert html =~ "Shared link saved"

      shared_link =
        Plausible.Repo.get_by(Plausible.Site.SharedLink,
          name: "Limited to Scandinavia",
          site_id: site.id,
          segment_id: segment.id
        )

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

    test "renders form fields for editing a shared link (not limited to segment, not protected)",
         %{
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
      refute html =~ "Password protect"
      assert html =~ "Limit to segment"
      refute element_exists?(html, ~s|button#password-protect-[role="switch"]|)
      refute element_exists?(html, ~s|input[name="shared_link[password]"][type="password"]|)
      assert element_exists?(html, ~s|input[name="shared_link[segment_id]"][value=""]|)

      assert element_exists?(
               html,
               ~s|a[href="https://plausible.io/docs/filters-segments#how-to-save-a-segment"]|
             )
    end

    test "renders form fields for editing a shared link (limited to segment, protected)", %{
      conn: conn,
      site: site,
      session: session
    } do
      segment = insert(:segment, type: :site, site: site, name: "Scandinavia")

      shared_link =
        insert(:shared_link,
          site: site,
          name: "Existing Link",
          segment: segment,
          password: "secret123"
        )

      lv = get_liveview(conn, session)

      lv
      |> element(~s/button[phx-click="edit-shared-link"][phx-value-slug="#{shared_link.slug}"]/)
      |> render_click()

      html = render(lv)
      assert html =~ "Edit shared link"
      assert element_exists?(html, ~s|input[name="shared_link[name]"]|)
      assert html =~ ~s|value="#{shared_link.name}"|
      refute html =~ "Password protect"
      assert html =~ "Limit to segment"
      assert element_exists?(html, ~s|input[name="shared_link[segment_id]"]|)
      refute element_exists?(html, ~s|input[name="shared_link[password]"][type="password"]|)

      assert element_exists?(
               html,
               ~s|input[name="shared_link[segment_id]"][value="#{segment.id}"]|
             )

      assert html =~ ~s|value="#{segment.name}"|
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

    test "attaches a valid same-site segment when editing a shared link", %{
      conn: conn,
      site: site,
      session: session
    } do
      segment = insert(:segment, type: :site, site: site, name: "Scandinavia")
      shared_link = insert(:shared_link, site: site, name: "My Link")

      lv = get_liveview(conn, session)

      lv
      |> element(~s/button[phx-click="edit-shared-link"][phx-value-slug="#{shared_link.slug}"]/)
      |> render_click()

      lv
      |> find_form()
      |> render_submit(%{shared_link: %{name: "My Link", segment_id: segment.id}})

      html = render(lv)
      assert html =~ "Shared link saved"

      updated = Plausible.Repo.reload!(shared_link)
      assert updated.segment_id == segment.id
    end

    test "clears a segment when editing a shared link with segment_id empty", %{
      conn: conn,
      site: site,
      session: session
    } do
      segment = insert(:segment, type: :site, site: site, name: "Scandinavia")
      shared_link = insert(:shared_link, site: site, name: "My Link", segment: segment)

      lv = get_liveview(conn, session)

      lv
      |> element(~s/button[phx-click="edit-shared-link"][phx-value-slug="#{shared_link.slug}"]/)
      |> render_click()

      # Toggle off → ComboBox submits segment_id: ""
      lv
      |> find_form()
      |> render_submit(%{shared_link: %{name: "My Link", segment_id: ""}})

      html = render(lv)
      assert html =~ "Shared link saved"

      updated = Plausible.Repo.reload!(shared_link)
      assert is_nil(updated.segment_id)
    end

    test "does not associate a segment from another site when creating a shared link", %{
      conn: conn,
      site: site,
      session: session
    } do
      victim_site = insert(:site)
      victim_segment = insert(:segment, type: :site, site: victim_site, name: "Victim Segment")

      lv = get_liveview(conn, session)

      lv |> element("button#add-shared-link-button") |> render_click()

      lv
      |> find_form()
      |> render_submit(%{
        shared_link: %{name: "Attacker Link", segment_id: victim_segment.id}
      })

      html = render(lv)
      assert html =~ "Attacker Link"
      assert html =~ "Shared link saved"

      # The shared link must NOT reference the foreign segment
      shared_link =
        Plausible.Repo.get_by(Plausible.Site.SharedLink,
          name: "Attacker Link",
          site_id: site.id
        )

      assert shared_link
      assert is_nil(shared_link.segment_id)
    end

    test "does not associate a segment from another site when editing a shared link", %{
      conn: conn,
      site: site,
      session: session
    } do
      own_segment = insert(:segment, type: :site, site: site, name: "Own Segment")
      shared_link = insert(:shared_link, site: site, name: "My Link", segment: own_segment)

      victim_site = insert(:site)
      victim_segment = insert(:segment, type: :site, site: victim_site, name: "Victim Segment")

      lv = get_liveview(conn, session)

      lv
      |> element(~s/button[phx-click="edit-shared-link"][phx-value-slug="#{shared_link.slug}"]/)
      |> render_click()

      lv
      |> find_form()
      |> render_submit(%{
        shared_link: %{name: "My Link", segment_id: victim_segment.id}
      })

      html = render(lv)
      assert html =~ "Shared link saved"

      # The shared link must NOT be updated to reference the foreign segment
      updated = Plausible.Repo.reload!(shared_link)
      assert is_nil(updated.segment_id)
    end

    test "keeps the segment when editing a link whose segment was downgraded to personal", %{
      conn: conn,
      site: site,
      session: session
    } do
      # A site segment is attached, then later downgraded to personal. Editing the
      # link (e.g. renaming) must NOT detach the now-personal segment.
      segment = insert(:segment, type: :site, site: site, name: "Scandinavia")
      shared_link = insert(:shared_link, site: site, name: "My Link", segment: segment)

      Plausible.Repo.update!(Ecto.Changeset.change(segment, type: :personal))

      lv = get_liveview(conn, session)

      lv
      |> element(~s/button[phx-click="edit-shared-link"][phx-value-slug="#{shared_link.slug}"]/)
      |> render_click()

      lv
      |> find_form()
      |> render_submit(%{shared_link: %{name: "Renamed Link", segment_id: segment.id}})

      html = render(lv)
      assert html =~ "Shared link saved"

      updated = Plausible.Repo.reload!(shared_link)
      assert updated.name == "Renamed Link"

      assert updated.segment_id == segment.id,
             "Downgraded segment must stay attached to the shared link"
    end

    test "cannot overwrite the shared link slug via form params", %{
      conn: conn,
      site: site,
      session: session
    } do
      shared_link = insert(:shared_link, site: site, name: "Original Link")
      original_slug = shared_link.slug

      lv = get_liveview(conn, session)

      lv
      |> element(~s/button[phx-click="edit-shared-link"][phx-value-slug="#{original_slug}"]/)
      |> render_click()

      # Attempt to inject a custom slug through the form params
      lv
      |> find_form()
      |> render_submit(%{shared_link: %{name: "Original Link", slug: "evil-custom-slug"}})

      html = render(lv)
      assert html =~ "Shared link saved"

      updated = Plausible.Repo.reload!(shared_link)
      assert updated.slug == original_slug, "Slug must remain unchanged after update"
      refute updated.slug == "evil-custom-slug"
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
