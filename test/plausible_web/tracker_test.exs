defmodule PlausibleWeb.TrackerTest do
  use Plausible.DataCase, async: true
  use Plausible.Teams.Test

  describe "plausible-main.js" do
    @example_config %{
      "404" => true,
      "hash" => true,
      "file-downloads" => false,
      "outbound-links" => false,
      "pageview-props" => false,
      "tagged-events" => true,
      "revenue" => false
    }

    test "can calculate config" do
      site =
        new_site()
        |> Plausible.Sites.update_installation_meta!(%{script_config: @example_config})

      assert PlausibleWeb.Tracker.plausible_main_config(site) == %{
               domain: site.domain,
               endpoint: "#{PlausibleWeb.Endpoint.url()}/api/event",
               hash: true,
               outboundLinks: false,
               fileDownloads: false,
               pageviewProps: false,
               taggedEvents: true,
               revenue: false,
               local: false,
               manual: false
             }
    end

    test "can turn config into a script tag" do
      site =
        new_site()
        |> Plausible.Sites.update_installation_meta!(%{script_config: @example_config})

      script_tag = PlausibleWeb.Tracker.plausible_main_script_tag(site)

      assert script_tag =~
               ~s(={endpoint:"#{PlausibleWeb.Endpoint.url()}/api/event",domain:"#{site.domain}",taggedEvents:!0,hash:!0})
    end

    test "script tag escapes problematic characters as expected" do
      site =
        new_site()
        |> Plausible.Sites.update_installation_meta!(%{script_config: @example_config})
        |> Map.merge(%{domain: "naughty domain &amp;<> \"\'\nfoo "})

      script_tag = PlausibleWeb.Tracker.plausible_main_script_tag(site)

      assert script_tag =~ ~s(domain:"naughty domain &amp;<> \\"'\\nfoo ")
    end
  end
end
