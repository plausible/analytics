defmodule Plausible.Site.TrackerScriptConfigurationTest do
  use Plausible
  use Plausible.DataCase, async: true
  use Plausible.Teams.Test

  alias Plausible.Site.TrackerScriptConfiguration

  test "#upsert/2" do
    site = insert(:site)

    {:ok, initial_configuration} =
      TrackerScriptConfiguration.upsert(%{
        site_id: site.id,
        installation_type: nil,
        track_404_pages: true,
        hash_based_routing: true,
        outbound_links: true,
        pageview_props: true
      })

    assert_matches %{
                     id: ^any(:string),
                     site_id: ^site.id,
                     installation_type: nil,
                     track_404_pages: true,
                     hash_based_routing: true,
                     outbound_links: true,
                     file_downloads: false,
                     revenue_tracking: false,
                     tagged_events: false,
                     form_submissions: false,
                     pageview_props: true
                   } = initial_configuration

    {:ok, updated_configuration} =
      TrackerScriptConfiguration.upsert(%{
        site_id: site.id,
        installation_type: :wordpress,
        track_404_pages: false,
        outbound_links: true,
        file_downloads: true,
        pageview_props: false
      })

    assert_matches %{
                     id: ^initial_configuration.id,
                     site_id: ^site.id,
                     installation_type: :wordpress,
                     track_404_pages: false,
                     hash_based_routing: true,
                     outbound_links: true,
                     file_downloads: true,
                     revenue_tracking: false,
                     tagged_events: false,
                     form_submissions: false,
                     pageview_props: false
                   } = updated_configuration
  end
end
