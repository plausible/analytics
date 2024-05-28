defmodule Plausible.Shield.HostnameRuleCacheTest do
  use Plausible.DataCase, async: true

  alias Plausible.Shield.HostnameRule
  alias Plausible.Shield.HostnameRuleCache
  alias Plausible.Shields

  describe "public cache interface" do
    test "cache caches hostname rules", %{test: test} do
      cache_opts = [force?: true, cache_name: test]

      {:ok, _} =
        Supervisor.start_link(
          [
            {HostnameRuleCache,
             [cache_name: test, child_id: :hostname_rules_cache_id, ets_options: [:bag]]}
          ],
          strategy: :one_for_one,
          name: :"cache_supervisor_#{test}"
        )

      site1 = insert(:site)
      site2 = insert(:site)

      {:ok, %{id: rid1}} = Shields.add_hostname_rule(site1, %{"hostname" => "1.example.com"})
      {:ok, %{id: rid2}} = Shields.add_hostname_rule(site1, %{"hostname" => "2.example.com"})
      {:ok, %{id: rid3}} = Shields.add_hostname_rule(site2, %{"hostname" => "3.example.com"})

      :ok = HostnameRuleCache.refresh_all(cache_name: test)

      :ok = Shields.remove_hostname_rule(site1, rid1)

      # cache is stale
      assert HostnameRuleCache.size(test) == 3

      # the rule order should be deterministic, but with 1s timestamp sorting precision
      # race conditions may happen during tests
      assert rules = HostnameRuleCache.get(site1.domain, cache_opts)
      rule_ids = Enum.map(rules, & &1.id)
      assert rid1 in rule_ids
      assert rid2 in rule_ids
      assert length(rules) == 2

      assert %HostnameRule{from_cache?: true, id: ^rid3} =
               HostnameRuleCache.get(site2.domain, cache_opts)

      refute HostnameRuleCache.get("rogue.example.com", cache_opts)
    end

    test "hostname path patterns are already compiled when fetched from cache", %{test: test} do
      site = insert(:site)

      {:ok, _} = start_test_cache(test)
      cache_opts = [force?: true, cache_name: test]

      {:ok, _} = Shields.add_hostname_rule(site, %{"hostname" => "*example.com"})
      :ok = HostnameRuleCache.refresh_all(cache_name: test)
      assert regex = HostnameRuleCache.get(site.domain, cache_opts).hostname_pattern
      assert regex == ~r/^.*example\.com$/
    end

    test "cache allows lookups for hostname paths on sites with changed domain", %{test: test} do
      {:ok, _} = start_test_cache(test)
      cache_opts = [force?: true, cache_name: test]
      site = insert(:site, domain: "new.example.com", domain_changed_from: "old.example.com")

      {:ok, _} = Shields.add_hostname_rule(site, %{"hostname" => "#{test}"})
      :ok = HostnameRuleCache.refresh_all(cache_name: test)

      assert HostnameRuleCache.get("old.example.com", cache_opts)
      assert HostnameRuleCache.get("new.example.com", cache_opts)
      refute HostnameRuleCache.get("rogue.example.com", cache_opts)
    end

    test "refreshes only recently added hostnames rules", %{test: test} do
      {:ok, _} = start_test_cache(test)

      domain = "site1.example.com"
      site = insert(:site, domain: domain)

      cache_opts = [cache_name: test, force?: true]

      yesterday =
        NaiveDateTime.utc_now()
        |> NaiveDateTime.add(-1 * 60 * 60 * 24)
        |> NaiveDateTime.truncate(:second)

      {:ok, r1} = Plausible.Shields.add_hostname_rule(site, %{"hostname" => "test1.example.com"})
      Ecto.Changeset.change(r1, inserted_at: yesterday, updated_at: yesterday) |> Repo.update!()
      {:ok, _} = Plausible.Shields.add_hostname_rule(site, %{"hostname" => "test2.example.com"})

      assert HostnameRuleCache.get(domain, cache_opts) == nil

      assert :ok = HostnameRuleCache.refresh_updated_recently(cache_opts)

      assert %{hostname_pattern: ~r/^test2\.example\.com$/} =
               HostnameRuleCache.get(domain, cache_opts)

      assert :ok = HostnameRuleCache.refresh_all(cache_opts)

      assert [_, _] = HostnameRuleCache.get(domain, cache_opts)
    end
  end

  test "get_from_source", %{test: test} do
    {:ok, _} = start_test_cache(test)

    domain = "site1.example.com"
    site = insert(:site, domain: domain)

    cache_opts = [cache_name: test, force?: true]

    {:ok, _} = Shields.add_hostname_rule(site, %{"hostname" => "#{test}"})
    {:ok, _} = Shields.add_hostname_rule(site, %{"hostname" => "#{test}*"})

    :ok = HostnameRuleCache.refresh_all(cache_opts)

    assert length(HostnameRuleCache.get(domain, cache_opts)) ==
             length(HostnameRuleCache.get_from_source(domain))
  end

  defp start_test_cache(cache_name) do
    %{start: {m, f, a}} =
      HostnameRuleCache.child_spec(cache_name: cache_name, ets_options: [:bag])

    apply(m, f, a)
  end
end
