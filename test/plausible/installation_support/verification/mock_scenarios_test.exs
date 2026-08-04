defmodule Plausible.InstallationSupport.Verification.MockScenariosTest do
  use Plausible.DataCase, async: true

  on_ee do
    alias Plausible.InstallationSupport.Verification.MockScenarios

    test "get/1 returns nil for a domain with no registered scenario" do
      site = insert(:site)

      assert MockScenarios.get(site.domain) == nil
    end

    test "put/3 registers a scenario, get/1 returns it" do
      site = insert(:site)

      :ok = MockScenarios.put(site.domain, :success, [])

      assert MockScenarios.get(site.domain) == %{
               interpretation_result: :success,
               slowdown: nil,
               launch_delay: nil
             }
    end

    test "put/3 stores a slowdown opt alongside the interpretation result" do
      site = insert(:site)

      :ok = MockScenarios.put(site.domain, :domain_not_found, slowdown: 2000)

      assert MockScenarios.get(site.domain) == %{
               interpretation_result: :domain_not_found,
               slowdown: 2000,
               launch_delay: nil
             }
    end

    test "put/3 stores a launch_delay opt alongside the interpretation result" do
      site = insert(:site)

      :ok = MockScenarios.put(site.domain, :domain_not_found, launch_delay: 2000)

      assert MockScenarios.get(site.domain) == %{
               interpretation_result: :domain_not_found,
               slowdown: nil,
               launch_delay: 2000
             }
    end

    test "put/3 overwrites a previously registered scenario for the same domain" do
      site = insert(:site)

      :ok = MockScenarios.put(site.domain, :success, [])
      :ok = MockScenarios.put(site.domain, :csp_disallowed, [])

      assert MockScenarios.get(site.domain) == %{
               interpretation_result: :csp_disallowed,
               slowdown: nil,
               launch_delay: nil
             }
    end

    test "scenarios registered for one domain never leak into another domain on the same registry" do
      site_a = insert(:site)
      site_b = insert(:site)

      :ok = MockScenarios.put(site_a.domain, :success, [])
      :ok = MockScenarios.put(site_b.domain, :domain_not_found, slowdown: 500, launch_delay: 100)

      assert MockScenarios.get(site_a.domain) == %{
               interpretation_result: :success,
               slowdown: nil,
               launch_delay: nil
             }

      assert MockScenarios.get(site_b.domain) == %{
               interpretation_result: :domain_not_found,
               slowdown: 500,
               launch_delay: 100
             }

      :ok = MockScenarios.put(site_a.domain, :csp_disallowed, [])

      assert MockScenarios.get(site_b.domain) == %{
               interpretation_result: :domain_not_found,
               slowdown: 500,
               launch_delay: 100
             }
    end
  end
end
