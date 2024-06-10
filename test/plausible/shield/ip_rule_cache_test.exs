defmodule Plausible.Shield.IPRuleCacheTest do
  use Plausible.DataCase, async: true

  alias Plausible.Shield.IPRule
  alias Plausible.Shield.IPRuleCache
  alias Plausible.Shields

  describe "public cache interface" do
    test "cache caches IP rules", %{test: test} do
      {:ok, _} =
        Supervisor.start_link([{IPRuleCache, [cache_name: test, child_id: :ip_rules_cache_id]}],
          strategy: :one_for_one,
          name: :"cache_supervisor_#{test}"
        )

      site = insert(:site, domain: "site1.example.com")

      {:ok, %{id: rid1}} = Shields.add_ip_rule(site, %{"inet" => "1.1.1.1"})
      {:ok, %{id: rid2}} = Shields.add_ip_rule(site, %{"inet" => "2.2.2.2"})

      :ok = IPRuleCache.refresh_all(cache_name: test)

      :ok = Shields.remove_ip_rule(site, rid1)

      assert IPRuleCache.size(test) == 2

      assert %IPRule{from_cache?: true, id: ^rid1} =
               IPRuleCache.get({site.domain, "1.1.1.1"}, force?: true, cache_name: test)

      assert %IPRule{from_cache?: true, id: ^rid2} =
               IPRuleCache.get({site.domain, "2.2.2.2"}, force?: true, cache_name: test)

      refute IPRuleCache.get({site.domain, "3.3.3.3"}, cache_name: test, force?: true)
    end

    test "cache allows IP lookups for sites with changed domain", %{test: test} do
      {:ok, _} = start_test_cache(test)
      site = insert(:site, domain: "new.example.com", domain_changed_from: "old.example.com")

      {:ok, _} = Shields.add_ip_rule(site, %{"inet" => "1.1.1.1"})
      :ok = IPRuleCache.refresh_all(cache_name: test)

      assert IPRuleCache.get({"old.example.com", "1.1.1.1"}, force?: true, cache_name: test)
      assert IPRuleCache.get({"new.example.com", "1.1.1.1"}, force?: true, cache_name: test)
    end

    test "refreshes only recently added rules", %{test: test} do
      {:ok, _} = start_test_cache(test)

      domain = "site1.example.com"
      site = insert(:site, domain: domain)

      cache_opts = [cache_name: test, force?: true]

      yesterday = DateTime.utc_now() |> DateTime.add(-1 * 60 * 60 * 24)

      insert(:ip_rule,
        site: site,
        inserted_at: yesterday,
        updated_at: yesterday,
        inet: "1.1.1.1"
      )

      insert(:ip_rule, site: site, inet: "2.2.2.2")

      assert IPRuleCache.get({domain, "1.1.1.1"}, cache_opts) == nil
      assert IPRuleCache.get({domain, "2.2.2.2"}, cache_opts) == nil

      assert :ok = IPRuleCache.refresh_updated_recently(cache_opts)

      refute IPRuleCache.get({domain, "1.1.1.1"}, cache_opts)
      assert %IPRule{} = IPRuleCache.get({domain, "2.2.2.2"}, cache_opts)
    end
  end

  defp start_test_cache(cache_name) do
    %{start: {m, f, a}} = IPRuleCache.child_spec(cache_name: cache_name)
    apply(m, f, a)
  end
end
