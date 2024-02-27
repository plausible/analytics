defmodule Plausible.Shield.CountryRuleCacheTest do
  use Plausible.DataCase, async: true

  alias Plausible.Shield.CountryRule
  alias Plausible.Shield.CountryRuleCache
  alias Plausible.Shields

  describe "public cache interface" do
    test "cache caches country rules", %{test: test} do
      {:ok, _} =
        Supervisor.start_link(
          [{CountryRuleCache, [cache_name: test, child_id: :country_rules_cache_id]}],
          strategy: :one_for_one,
          name: :"cache_supervisor_#{test}"
        )

      site = insert(:site, domain: "site1.example.com")

      {:ok, %{id: rid1}} = Shields.add_country_rule(site, %{"country_code" => "EE"})
      {:ok, %{id: rid2}} = Shields.add_country_rule(site, %{"country_code" => "PL"})

      :ok = CountryRuleCache.refresh_all(cache_name: test)

      :ok = Shields.remove_country_rule(site, rid1)

      assert CountryRuleCache.size(test) == 2

      assert %CountryRule{from_cache?: true, id: ^rid1} =
               CountryRuleCache.get({site.domain, "EE"}, force?: true, cache_name: test)

      assert %CountryRule{from_cache?: true, id: ^rid2} =
               CountryRuleCache.get({site.domain, "PL"}, force?: true, cache_name: test)

      refute CountryRuleCache.get({site.domain, "RO"}, cache_name: test, force?: true)
    end

    test "cache allows lookups for countries on sites with changed domain", %{test: test} do
      {:ok, _} = start_test_cache(test)
      site = insert(:site, domain: "new.example.com", domain_changed_from: "old.example.com")

      {:ok, _} = Shields.add_country_rule(site, %{"country_code" => "EE"})
      :ok = CountryRuleCache.refresh_all(cache_name: test)

      assert CountryRuleCache.get({"old.example.com", "EE"}, force?: true, cache_name: test)
      assert CountryRuleCache.get({"new.example.com", "EE"}, force?: true, cache_name: test)
    end

    test "refreshes only recently added country rules", %{test: test} do
      {:ok, _} = start_test_cache(test)

      domain = "site1.example.com"
      site = insert(:site, domain: domain)

      cache_opts = [cache_name: test, force?: true]

      yesterday = DateTime.utc_now() |> DateTime.add(-1 * 60 * 60 * 24)

      insert(:country_rule,
        site: site,
        inserted_at: yesterday,
        updated_at: yesterday,
        country_code: "EE"
      )

      insert(:country_rule, site: site, country_code: "PL")

      assert CountryRuleCache.get({domain, "EE"}, cache_opts) == nil
      assert CountryRuleCache.get({domain, "PL"}, cache_opts) == nil

      assert :ok = CountryRuleCache.refresh_updated_recently(cache_opts)

      refute CountryRuleCache.get({domain, "EE"}, cache_opts)
      assert %CountryRule{} = CountryRuleCache.get({domain, "PL"}, cache_opts)
    end
  end

  defp start_test_cache(cache_name) do
    %{start: {m, f, a}} = CountryRuleCache.child_spec(cache_name: cache_name)
    apply(m, f, a)
  end
end
