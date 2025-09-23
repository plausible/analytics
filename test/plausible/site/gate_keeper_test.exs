defmodule Plausible.Site.GateKeeperTest do
  use Plausible.DataCase, async: true
  use Plausible.Teams.Test

  alias Plausible.Site.Cache
  alias Plausible.Site.GateKeeper

  setup %{test: test} do
    {:ok, _} = start_test_cache(test)
    opts = [cache_opts: [cache_name: test, force?: true]]
    {:ok, %{opts: opts}}
  end

  test "sites not found in cache are denied", %{opts: opts} do
    assert {:deny, :not_found} = GateKeeper.check("example.com", opts)
  end

  test "consolidated sites should be treated as not found", %{opts: opts, test: test} do
    consolidated_site =
      add_site_and_refresh_cache(test, domain: "consolidated.example.com", consolidated: true)

    assert {:deny, :not_found} = GateKeeper.check("consolidated.example.com", opts)

    Plausible.Cache.Adapter.put(test, "consolidated.example.com", consolidated_site)

    assert {:deny, :not_found} = GateKeeper.check("consolidated.example.com", opts)
  end

  test "sites with accepted_traffic_until < now are denied", %{test: test, opts: opts} do
    domain = "expired.example.com"
    yesterday = Date.utc_today() |> Date.add(-1)

    owner = new_user(team: [accept_traffic_until: yesterday])

    %{id: _} =
      add_site_and_refresh_cache(test,
        domain: domain,
        owner: owner
      )

    assert {:deny, :payment_required} = GateKeeper.check(domain, opts)
  end

  test "site from cache with no ingest_rate_limit_threshold is allowed", %{test: test, opts: opts} do
    domain = "site1.example.com"

    %{id: site_id} = add_site_and_refresh_cache(test, domain: domain)

    assert {:allow, %Plausible.Site{id: ^site_id, from_cache?: true}} =
             GateKeeper.check(domain, opts)
  end

  test "rate limiting works with threshold", %{test: test, opts: opts} do
    domain = "site1.example.com"

    %{id: site_id} =
      add_site_and_refresh_cache(test,
        domain: domain,
        ingest_rate_limit_threshold: 1,
        ingest_rate_limit_scale_seconds: 60
      )

    assert {:allow, %Plausible.Site{id: ^site_id, from_cache?: true}} =
             GateKeeper.check(domain, opts)

    assert {:deny, :throttle} = GateKeeper.check(domain, opts)
    assert {:deny, :throttle} = GateKeeper.check(domain, opts)
  end

  @tag :slow
  test "rate limiting works with scale window", %{test: test, opts: opts} do
    domain = "site1.example.com"

    %{id: site_id} =
      add_site_and_refresh_cache(test,
        domain: domain,
        ingest_rate_limit_threshold: 1,
        ingest_rate_limit_scale_seconds: 1
      )

    assert {:allow, %Plausible.Site{id: ^site_id, from_cache?: true}} =
             GateKeeper.check(domain, opts)

    Process.sleep(1)
    assert {:deny, :throttle} = GateKeeper.check(domain, opts)
    Process.sleep(1_000)

    assert {:allow, %Plausible.Site{id: ^site_id, from_cache?: true}} =
             GateKeeper.check(domain, opts)
  end

  test "rate limiting prioritises cache lookups", %{test: test, opts: opts} do
    domain = "site1.example.com"

    site =
      add_site_and_refresh_cache(test,
        domain: domain,
        ingest_rate_limit_threshold: 1000,
        ingest_rate_limit_scale_seconds: 600
      )

    {:ok, _} = Plausible.Repo.delete(site)
    # We need some dummy site, otherwise the cache won't refresh in case the DB
    # is completely empty
    new_site()
    deleted_site_id = site.id

    assert {:allow, %Plausible.Site{id: ^deleted_site_id, from_cache?: true}} =
             GateKeeper.check(domain, opts)

    :ok = Cache.refresh_all(opts[:cache_opts])
    assert {:deny, :not_found} = GateKeeper.check(domain, opts)
  end

  defp start_test_cache(cache_name) do
    %{start: {m, f, a}} = Cache.child_spec(cache_name: cache_name)
    apply(m, f, a)
  end

  defp add_site_and_refresh_cache(cache_name, site_data) do
    site = new_site(site_data)

    Cache.refresh_updated_recently(cache_name: cache_name, force?: true)
    site
  end
end
