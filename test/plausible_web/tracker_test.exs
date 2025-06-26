defmodule PlausibleWeb.TrackerTest do
  use Plausible.DataCase, async: true
  use Oban.Testing, repo: Plausible.Repo
  use Plausible
  use Plausible.Teams.Test

  alias Plausible.Site.TrackerScriptConfiguration
  alias PlausibleWeb.Tracker

  describe "plausible-web.js" do
    @example_config %{
      installation_type: :manual,
      track_404_pages: true,
      hash_based_routing: true,
      file_downloads: false,
      outbound_links: false,
      pageview_props: false,
      tagged_events: true,
      revenue_tracking: false,
      form_submissions: true
    }

    test "can calculate config" do
      site = new_site()
      tracker_script_configuration = create_config(site)

      assert PlausibleWeb.Tracker.plausible_main_config(tracker_script_configuration) == %{
               domain: site.domain,
               endpoint: "#{PlausibleWeb.Endpoint.url()}/api/event",
               outboundLinks: false,
               fileDownloads: false,
               formSubmissions: true
             }
    end

    test "can create config with params" do
      site = new_site()

      tracker_script_configuration =
        Tracker.get_or_create_tracker_script_configuration!(site, %{
          outbound_links: true,
          form_submissions: true,
          installation_type: :manual
        })

      assert tracker_script_configuration.outbound_links
      assert tracker_script_configuration.form_submissions
      refute tracker_script_configuration.file_downloads
      assert tracker_script_configuration.installation_type == :manual
    end

    test "goals are created when config is created" do
      site = new_site()

      Tracker.get_or_create_tracker_script_configuration!(site, %{
        outbound_links: true,
        installation_type: :manual
      })

      assert Repo.get_by(Plausible.Goal, site_id: site.id, display_name: "Outbound Link: Click")
      refute Repo.get_by(Plausible.Goal, site_id: site.id, display_name: "File Download")
    end

    test "can update config" do
      site = new_site()
      tracker_script_configuration = create_config(site)

      assert tracker_script_configuration.installation_type == :manual

      Tracker.update_script_configuration(
        site,
        %{installation_type: :wordpress, outbound_links: true},
        :installation
      )

      tracker_script_configuration = Repo.reload!(tracker_script_configuration)

      assert tracker_script_configuration.installation_type == :wordpress
      assert tracker_script_configuration.outbound_links == true
    end

    on_ee do
      test "CDN purge is scheduled when config is updated" do
        site = new_site()

        tracker_script_configuration =
          Tracker.get_or_create_tracker_script_configuration!(site)

        Tracker.update_script_configuration(
          site,
          %{installation_type: :wordpress, outbound_links: true},
          :installation
        )

        assert_enqueued(
          worker: Plausible.Workers.PurgeCDNCache,
          args: %{id: tracker_script_configuration.id}
        )
      end

      test "CDN purge is not scheduled when only installation type is updated" do
        site = new_site()

        tracker_script_configuration =
          Tracker.get_or_create_tracker_script_configuration!(site)

        Tracker.update_script_configuration(site, %{installation_type: :wordpress}, :installation)

        refute_enqueued(
          worker: Plausible.Workers.PurgeCDNCache,
          args: %{id: tracker_script_configuration.id}
        )
      end
    end

    test "can turn config into a script tag" do
      site = new_site()
      tracker_script_configuration = create_config(site)

      script_tag = PlausibleWeb.Tracker.plausible_main_script_tag(tracker_script_configuration)

      assert script_tag =~
               ~s(={endpoint:"#{PlausibleWeb.Endpoint.url()}/api/event",domain:"#{site.domain}",formSubmissions:!0})
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
