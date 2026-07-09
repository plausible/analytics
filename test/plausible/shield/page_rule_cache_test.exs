defmodule Plausible.Shield.PageRuleCacheTest do
  use Plausible.DataCase, async: true

  alias Plausible.Shield.PageRule
  alias Plausible.Shield.PageRuleCache
  alias Plausible.Shields

  describe "public cache interface" do
    test "cache caches page rules", %{test: test} do
      cache_opts = [force?: true, cache_name: test]

      {:ok, _} =
        Supervisor.start_link(
          [
            {PageRuleCache,
             [cache_name: test, child_id: :page_rules_cache_id, ets_options: [:bag]]}
          ],
          strategy: :one_for_one,
          name: :"cache_supervisor_#{test}"
        )

      site1 = insert(:site)
      site2 = insert(:site)

      {:ok, %{id: rid1}} = Shields.add_page_rule(site1, %{"page_path" => "/test/1"})
      {:ok, %{id: rid2}} = Shields.add_page_rule(site1, %{"page_path" => "/test/2"})
      {:ok, %{id: rid3}} = Shields.add_page_rule(site2, %{"page_path" => "/test/2"})

      :ok = PageRuleCache.refresh_all(cache_name: test)

      :ok = Shields.remove_page_rule(site1, rid1)

      assert PageRuleCache.size(test) == 3

      # the rule order should be deterministic, but with 1s timestamp sorting precision
      # race conditions may happen during tests
      assert rules = PageRuleCache.get(site1.domain, cache_opts)
      rule_ids = Enum.map(rules, & &1.id)
      assert rid1 in rule_ids
      assert rid2 in rule_ids
      assert length(rules) == 2

      assert %PageRule{from_cache?: true, id: ^rid3} =
               PageRuleCache.get(site2.domain, cache_opts)

      refute PageRuleCache.get("rogue.example.com", cache_opts)
    end

    test "page path patterns are already compiled when fetched from cache", %{test: test} do
      site = insert(:site)

      {:ok, _} = start_test_cache(test)
      cache_opts = [force?: true, cache_name: test]

      {:ok, _} = Shields.add_page_rule(site, %{"page_path" => "/hello/**/world"})
      :ok = PageRuleCache.refresh_all(cache_name: test)
      assert regex = PageRuleCache.get(site.domain, cache_opts).page_path_pattern
      assert regex == ~r/^\/hello\/.*\/world$/
    end

    test "cache allows lookups for page paths on sites with changed domain", %{test: test} do
      {:ok, _} = start_test_cache(test)
      cache_opts = [force?: true, cache_name: test]
      site = insert(:site, domain: "new.example.com", domain_changed_from: "old.example.com")

      {:ok, _} = Shields.add_page_rule(site, %{"page_path" => "/#{test}"})
      :ok = PageRuleCache.refresh_all(cache_name: test)

      assert PageRuleCache.get("old.example.com", cache_opts)
      assert PageRuleCache.get("new.example.com", cache_opts)
      refute PageRuleCache.get("rogue.example.com", cache_opts)
    end

    test "refreshes only recently added pages rules", %{test: test} do
      {:ok, _} = start_test_cache(test)

      domain = "site1.example.com"
      site = insert(:site, domain: domain)

      cache_opts = [cache_name: test, force?: true]

      yesterday =
        NaiveDateTime.utc_now()
        |> NaiveDateTime.add(-1 * 60 * 60 * 24)
        |> NaiveDateTime.truncate(:second)

      {:ok, r1} = Plausible.Shields.add_page_rule(site, %{"page_path" => "/test/1"})
      Ecto.Changeset.change(r1, inserted_at: yesterday, updated_at: yesterday) |> Repo.update!()
      {:ok, _} = Plausible.Shields.add_page_rule(site, %{"page_path" => "/test/2"})

      assert PageRuleCache.get(domain, cache_opts) == nil

      assert :ok = PageRuleCache.refresh_updated_recently(cache_opts)

      assert %{page_path_pattern: ~r[^/test/2$]} = PageRuleCache.get(domain, cache_opts)

      assert :ok = PageRuleCache.refresh_all(cache_opts)

      assert [_, _] = PageRuleCache.get(domain, cache_opts)
    end
  end

  defp start_test_cache(cache_name) do
    %{start: {m, f, a}} = PageRuleCache.child_spec(cache_name: cache_name, ets_options: [:bag])
    apply(m, f, a)
  end
end
