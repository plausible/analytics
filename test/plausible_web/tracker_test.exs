defmodule PlausibleWeb.TrackerTest do
  use Plausible.DataCase, async: true
  use Plausible.Teams.Test

  alias Plausible.Site.TrackerScriptConfiguration
  alias PlausibleWeb.Tracker

  describe "plausible-main.js" do
    @example_config %{
      installation_type: :manual,
      track_404_pages: true,
      hash_based_routing: true,
      file_downloads: false,
      outbound_links: false,
      pageview_props: false,
      tagged_events: true,
      revenue_tracking: false
    }

    test "can calculate config" do
      site = new_site()
      tracker_script_configuration = create_config(site)

      assert PlausibleWeb.Tracker.plausible_main_config(tracker_script_configuration) == %{
               domain: site.domain,
               endpoint: "#{PlausibleWeb.Endpoint.url()}/api/event",
               hash: true,
               outboundLinks: false,
               fileDownloads: false,
               taggedEvents: true,
               revenue: false,
               local: false,
               manual: false
             }
    end

    test "can turn config into a script tag" do
      site = new_site()
      tracker_script_configuration = create_config(site)

      script_tag = PlausibleWeb.Tracker.plausible_main_script_tag(tracker_script_configuration)

      assert script_tag =~
               ~s(={endpoint:"#{PlausibleWeb.Endpoint.url()}/api/event",domain:"#{site.domain}",taggedEvents:!0,hash:!0})
    end

    test "script tag escapes problematic characters as expected" do
      site = new_site(domain: "naughty domain &amp;<> \"\'\nfoo ")
      tracker_script_configuration = create_config(site)
      script_tag = PlausibleWeb.Tracker.plausible_main_script_tag(tracker_script_configuration)

      assert script_tag =~ ~s(domain:"naughty domain &amp;<> \\"'\\nfoo ")
    end

    def create_config(site) do
      Tracker.update_script_configuration(
        site,
        Map.put(@example_config, :site_id, site.id),
        :installation
      )

      Plausible.Repo.one(
        from(c in TrackerScriptConfiguration, where: c.site_id == ^site.id, preload: [:site])
      )
    end
  end
end
