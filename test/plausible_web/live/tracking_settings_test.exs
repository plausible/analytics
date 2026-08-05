defmodule PlausibleWeb.Live.TrackingSettingsTest do
  use PlausibleWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias Plausible.Site.TrackerScriptConfiguration

  setup [:create_user, :log_in, :create_site]

  describe "TrackingSettings LiveView" do
    test "renders the default measurements with their persisted state", %{
      conn: conn,
      site: site
    } do
      PlausibleWeb.Tracker.get_or_create_tracker_script_configuration!(site, %{
        outbound_links: true,
        file_downloads: false,
        form_submissions: true
      })

      html = conn |> get_liveview(site) |> render()

      assert html =~ "Default tracking"
      assert toggle_state(html, "outbound_links") == "true"
      assert toggle_state(html, "file_downloads") == "false"
      assert toggle_state(html, "form_submissions") == "true"
    end

    test "toggling a measurement persists it and shows a success message", %{
      conn: conn,
      site: site
    } do
      PlausibleWeb.Tracker.get_or_create_tracker_script_configuration!(site, %{
        outbound_links: true
      })

      lv = get_liveview(conn, site)

      html = toggle(lv, "outbound_links")

      assert html =~ "Outbound link tracking disabled"
      assert toggle_state(html, "outbound_links") == "false"
      refute configuration(site).outbound_links

      html = toggle(lv, "outbound_links")

      assert html =~ "Outbound link tracking enabled"
      assert toggle_state(html, "outbound_links") == "true"
      assert configuration(site).outbound_links
    end

    test "toggling a measurement syncs the corresponding goal", %{conn: conn, site: site} do
      PlausibleWeb.Tracker.get_or_create_tracker_script_configuration!(site, %{
        file_downloads: false
      })

      lv = get_liveview(conn, site)

      assert toggle(lv, "file_downloads") =~ "File download tracking enabled"

      assert Enum.any?(Plausible.Goals.for_site(site), &(&1.event_name == "File Download"))
    end

    test "lists the measurements that require manual setup", %{conn: conn, site: site} do
      html = conn |> get_liveview(site) |> render()

      assert html =~ "Additional tracking"
      assert html =~ "Custom event tracking"
      assert html =~ "404 error pages"
      assert html =~ "Hashed page paths"
      assert html =~ "Custom properties"
      assert html =~ "Ecommerce revenue"
      assert html =~ "https://plausible.io/docs/ecommerce-revenue-tracking"
    end

    test "links to the installation review flow", %{conn: conn, site: site} do
      html = conn |> get_liveview(site) |> render()

      assert html =~
               Routes.site_path(PlausibleWeb.Endpoint, :installation, site.domain,
                 flow: PlausibleWeb.Flows.review()
               )
    end

    @tag :ee_only
    test "shows active tracking status once installation has been verified", %{
      conn: conn,
      site: site
    } do
      site = set_onboarding_status(site, :completed)

      html = conn |> get_liveview(site) |> render()

      assert html =~ "Tracking status"
      assert html =~ "Active"
    end

    @tag :ee_only
    test "shows pending tracking status for a site that was never verified", %{
      conn: conn,
      site: site
    } do
      site = set_onboarding_status(site, :new_site)

      html = conn |> get_liveview(site) |> render()

      assert html =~ "Tracking status"
      assert html =~ "Installation pending"
    end

    @tag :ce_build_only
    test "does not show tracking status on CE", %{conn: conn, site: site} do
      site = set_onboarding_status(site, :new_site)

      html = conn |> get_liveview(site) |> render()

      refute html =~ "Tracking status"
      assert html =~ "https://plausible.io/docs/plausible-script"
    end
  end

  defp get_liveview(conn, site) do
    {:ok, lv, _html} =
      live_isolated(conn, PlausibleWeb.Live.TrackingSettings, session: %{"domain" => site.domain})

    lv
  end

  defp toggle(lv, field) do
    lv
    |> element(~s|button[phx-value-field="#{field}"]|)
    |> render_click()
  end

  defp toggle_state(html, field) do
    text_of_attr(html, ~s|button[phx-value-field="#{field}"]|, "aria-checked")
  end

  defp configuration(site) do
    Plausible.Repo.get_by!(TrackerScriptConfiguration, site_id: site.id)
  end

  defp set_onboarding_status(site, status) do
    site
    |> Ecto.Changeset.change(onboarding_status: status)
    |> Plausible.Repo.update!()
  end
end
