defmodule Plausible.ExportTest do
  use Plausible.DataCase

  test "it works" do
    site = insert(:site)

    populate_stats(site, [
      build(:pageview,
        user_id: 123,
        hostname: "export.dummy.site",
        pathname: "/",
        timestamp: ~U[2023-10-20 20:00:00Z]
      ),
      build(:pageview,
        user_id: 123,
        hostname: "export.dummy.site",
        pathname: "/about",
        timestamp: ~U[2023-10-20 20:01:00Z]
      ),
      build(:pageview,
        user_id: 123,
        hostname: "export.dummy.site",
        pathname: "/signup",
        timestamp: ~U[2023-10-20 20:03:20Z]
      )
    ])

    export = Plausible.Export.export(site.id)

    assert Map.keys(export) == [
             :browsers,
             :devices,
             :entry_pages,
             :exit_pages,
             :locations,
             :operating_systems,
             :pages,
             :sources,
             :visitors
           ]

    assert export.browsers == [
             %{
               bounces: 0,
               browser: "",
               date: ~D[2023-10-20],
               visit_duration: 200,
               visitors: 1,
               visits: 1
             }
           ]

    assert export.devices == [
             %{
               bounces: 0,
               date: ~D[2023-10-20],
               device: "",
               visit_duration: 200,
               visitors: 1,
               visits: 1
             }
           ]

    assert export.entry_pages == [
             %{
               bounces: 0,
               date: ~D[2023-10-20],
               entrances: 1,
               entry_page: "/",
               visit_duration: 200,
               visitors: 1
             }
           ]

    assert export.exit_pages == [
             %{date: ~D[2023-10-20], exit_page: "/signup", exits: 1, visitors: 1}
           ]

    # TODO region "" or nil
    assert export.locations == [
             %{
               bounces: 0,
               city: 0,
               country: "\0\0",
               date: ~D[2023-10-20],
               region: "-",
               visit_duration: 200,
               visitors: 1,
               visits: 1
             }
           ]

    assert export.operating_systems == [
             %{
               bounces: 0,
               date: ~D[2023-10-20],
               operating_system: "",
               visit_duration: 200,
               visitors: 1,
               visits: 1
             }
           ]

    assert export.pages == [
             %{
               date: ~D[2023-10-20],
               exits: 1,
               hostname: "export.dummy.site",
               pageviews: 1,
               path: "/signup",
               time_on_page: 0,
               visitors: 1
             },
             %{
               date: ~D[2023-10-20],
               exits: 0,
               hostname: "export.dummy.site",
               pageviews: 1,
               path: "/",
               time_on_page: 60,
               visitors: 1
             },
             %{
               date: ~D[2023-10-20],
               exits: 0,
               hostname: "export.dummy.site",
               pageviews: 1,
               path: "/about",
               time_on_page: 140,
               visitors: 1
             }
           ]

    assert export.sources == [
             %{
               bounces: 0,
               date: ~D[2023-10-20],
               source: "",
               utm_campaign: "",
               utm_content: "",
               utm_term: "",
               visit_duration: 200,
               visitors: 1,
               visits: 1
             }
           ]

    assert export.visitors == [
             %{
               bounces: 0,
               date: ~D[2023-10-20],
               pageviews: 3,
               visit_duration: 200,
               visitors: 1,
               visits: 1
             }
           ]
  end
end
