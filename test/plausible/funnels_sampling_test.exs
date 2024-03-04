defmodule Plausible.FunnelsSamplingTest do
  use Plausible.DataCase, async: false
  @moduletag :full_build_only

  use Plausible
  use Plausible.Test.Support.Journey

  # This test does a massive ingest, so we make sure the caches are utilized
  # (both Sites.Cache and UA parsing). We also ingest on all cores, where only
  # initially SipHash is a slow-down but warms up later on.
  # On 24 cores it takes around 5.5s.

  on_full_build do
    alias Plausible.Goals
    alias Plausible.Funnels
    alias Plausible.Stats

    setup do
      site = insert(:site)

      {:ok, g1} = Goals.create(site, %{"page_path" => "/go/to/blog/**"})
      {:ok, g2} = Goals.create(site, %{"event_name" => "Signup"})
      {:ok, g3} = Goals.create(site, %{"page_path" => "/checkout"})

      {:ok,
       %{
         site: site,
         goals: [g1, g2, g3],
         steps: [g1, g2, g3] |> Enum.map(&%{"goal_id" => &1.id})
       }}
    end

    setup_patch_env(Plausible.Cache, enabled: true)

    @tag :slow
    test "sampling", %{steps: [g1, g2, g3]} do
      site = insert(:site, domain: "1.1.1.1")

      {:ok, funnel} =
        Funnels.create(
          site,
          "From blog to signup",
          [g1, g2, g3]
        )

      Plausible.Site.Cache.refresh_all()
      journey = MassJourney

      journey site, manual: journey, ip: &random_ipv6/0, user_agent: "JourneyBrowser" do
        pageview "/go/to/blog/foo"
        custom_event "Signup"
        pageview "/checkout"
      end

      journey.run_many(50_000)

      query =
        Plausible.Stats.Query.from(site, %{"period" => "all", "sample_threshold" => "10000"})

      {:ok, funnel_data} = Stats.funnel(site, query, funnel.id)
      assert_in_delta funnel_data[:all_visitors], 50_000, 5000
    end
  end
end
