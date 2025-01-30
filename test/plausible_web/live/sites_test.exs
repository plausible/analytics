defmodule PlausibleWeb.Live.SitesTest do
  use PlausibleWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Plausible.Test.Support.HTML

  alias Plausible.Repo

  setup [:create_user, :log_in]

  describe "/sites" do
    test "renders empty sites page", %{conn: conn} do
      {:ok, _lv, html} = live(conn, "/sites")

      assert text(html) =~ "You don't have any sites yet"
    end

    @tag :ee_only
    test "renders ownership transfer invitation for a case with no plan", %{
      conn: conn,
      user: user
    } do
      site = insert(:site)

      invitation =
        insert(:invitation,
          site_id: site.id,
          inviter: build(:user),
          email: user.email,
          role: :owner
        )

      {:ok, _lv, html} = live(conn, "/sites")

      invitation_data = get_invitation_data(html)

      assert get_in(invitation_data, ["invitations", invitation.invitation_id, "no_plan"])
    end

    @tag :ee_only
    test "renders ownership transfer invitation for a case with exceeded limits", %{
      conn: conn,
      user: user
    } do
      site = insert(:site)

      insert(:growth_subscription, user: user)

      # fill site quota
      insert_list(10, :site, members: [user])

      invitation =
        insert(:invitation,
          site_id: site.id,
          inviter: build(:user),
          email: user.email,
          role: :owner
        )

      {:ok, _lv, html} = live(conn, "/sites")

      invitation_data = get_invitation_data(html)

      assert get_in(invitation_data, ["invitations", invitation.invitation_id, "exceeded_limits"]) ==
               "site limit"
    end

    @tag :ee_only
    test "renders ownership transfer invitation for a case with missing features", %{
      conn: conn,
      user: user
    } do
      site = insert(:site, allowed_event_props: ["dummy"])

      insert(:growth_subscription, user: user)

      invitation =
        insert(:invitation,
          site_id: site.id,
          inviter: build(:user),
          email: user.email,
          role: :owner
        )

      {:ok, _lv, html} = live(conn, "/sites")

      invitation_data = get_invitation_data(html)

      assert get_in(invitation_data, ["invitations", invitation.invitation_id, "missing_features"]) ==
               "Custom Properties"
    end

    test "renders 24h visitors correctly", %{conn: conn, user: user} do
      site = insert(:site, members: [user])

      populate_stats(site, [build(:pageview), build(:pageview), build(:pageview)])

      {:ok, _lv, html} = live(conn, "/sites")

      site_card = text_of_element(html, "li[data-domain=\"#{site.domain}\"]")
      assert site_card =~ "3 visitors in last 24h"
      assert site_card =~ site.domain
    end

    test "filters by domain", %{conn: conn, user: user} do
      _site1 = insert(:site, domain: "first.example.com", members: [user])
      _site2 = insert(:site, domain: "second.example.com", members: [user])
      _site3 = insert(:site, domain: "first-another.example.com", members: [user])

      {:ok, lv, _html} = live(conn, "/sites")

      type_into_input(lv, "filter_text", "first")
      html = render(lv)

      assert html =~ "first.example.com"
      assert html =~ "first-another.example.com"
      refute html =~ "second.example.com"
    end

    test "filtering plays well with pagination", %{conn: conn, user: user} do
      _site1 = insert(:site, domain: "first.another.example.com", members: [user])
      _site2 = insert(:site, domain: "second.example.com", members: [user])
      _site3 = insert(:site, domain: "third.another.example.com", members: [user])

      {:ok, lv, html} = live(conn, "/sites?page_size=2")

      assert html =~ "first.another.example.com"
      assert html =~ "second.example.com"
      refute html =~ "third.another.example.com"
      assert html =~ "page=2"
      refute html =~ "page=1"

      type_into_input(lv, "filter_text", "anot")
      html = render(lv)

      assert html =~ "first.another.example.com"
      refute html =~ "second.example.com"
      assert html =~ "third.another.example.com"
      refute html =~ "page=1"
      refute html =~ "page=2"
    end
  end

  describe "pinning" do
    test "renders pin site option when site not pinned", %{conn: conn, user: user} do
      site = insert(:site, members: [user])

      {:ok, _lv, html} = live(conn, "/sites")

      assert text_of_element(
               html,
               ~s/li[data-domain="#{site.domain}"] a[phx-value-domain]/
             ) == "Pin Site"
    end

    test "site state changes when pin toggled", %{conn: conn, user: user} do
      site = insert(:site, members: [user])

      {:ok, lv, _html} = live(conn, "/sites")

      button_selector = ~s/li[data-domain="#{site.domain}"] a[phx-value-domain]/

      html =
        lv
        |> element(button_selector)
        |> render_click()

      assert html =~ "Site pinned"

      assert text_of_element(html, button_selector) == "Unpin Site"

      html =
        lv
        |> element(button_selector)
        |> render_click()

      assert html =~ "Site unpinned"

      assert text_of_element(html, button_selector) == "Pin Site"
    end

    test "shows error when pins limit hit", %{conn: conn, user: user} do
      for _ <- 1..9 do
        site = insert(:site, members: [user])
        assert {:ok, _} = Plausible.Sites.toggle_pin(user, site)
      end

      site = insert(:site, members: [user])

      {:ok, lv, _html} = live(conn, "/sites")

      button_selector = ~s/li[data-domain="#{site.domain}"] a[phx-value-domain]/

      html =
        lv
        |> element(button_selector)
        |> render_click()

      assert text(html) =~ "Looks like you've hit the pinned sites limit!"
    end

    test "does not allow pinning site user doesn't have access to", %{conn: conn, user: user} do
      site = insert(:site)

      {:ok, lv, _html} = live(conn, "/sites")

      render_click(lv, "pin-toggle", %{"domain" => site.domain})

      refute Repo.get_by(Plausible.Site.UserPreference, user_id: user.id, site_id: site.id)
    end
  end

  defp type_into_input(lv, id, text) do
    lv
    |> element("form")
    |> render_change(%{id => text})
  end

  defp get_invitation_data(html) do
    html
    |> text_of_attr("div[x-data]", "x-data")
    |> String.trim("dropdown")
    |> String.replace("selectedInvitation:", "\"selectedInvitation\":")
    |> String.replace("invitationOpen:", "\"invitationOpen\":")
    |> String.replace("invitations:", "\"invitations\":")
    |> Jason.decode!()
  end
end
