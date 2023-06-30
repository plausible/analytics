defmodule Plausible.Site.GateKeeperTest do
  use Plausible.DataCase, async: true

  alias Plausible.Site.Cache
  alias Plausible.Site.GateKeeper

  import ExUnit.CaptureLog

  setup %{test: test} do
    {:ok, _} = start_test_cache(test)
    opts = [cache_opts: [cache_name: test, force?: true]]
    {:ok, %{opts: opts}}
  end

  test "sites not found in cache are denied", %{opts: opts} do
    assert {:deny, :not_found} = GateKeeper.check("example.com", opts)
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
    insert(:site)
    deleted_site_id = site.id

    assert {:allow, %Plausible.Site{id: ^deleted_site_id, from_cache?: true}} =
             GateKeeper.check(domain, opts)

    :ok = Cache.refresh_all(opts[:cache_opts])
    assert {:deny, :not_found} = GateKeeper.check(domain, opts)
  end

  test "rate limiter policy switches to allow when RL backend errors bubble-up", %{
    test: test,
    opts: opts
  } do
    domain = "causingerrors.example.com"

    site =
      add_site_and_refresh_cache(test,
        domain: domain,
        ingest_rate_limit_threshold: 1,
        ingest_rate_limit_scale_seconds: 600
      )

    site_id = site.id

    assert {:allow, %Plausible.Site{id: ^site_id, from_cache?: true}} =
             GateKeeper.check(domain, opts)

    assert {:deny, :throttle} = GateKeeper.check(domain, opts)

    {:ok, :broken} = break_hammer(site)

    log =
      capture_log(fn ->
        assert {:allow, %Plausible.Site{id: ^site_id, from_cache?: true}} =
                 GateKeeper.check(domain, opts)
      end)

    assert log =~ "Error checking rate limit for 'ingest:site:causingerrors.example.com'"
    assert log =~ "Falling back to: :allow"
  end

  # We need a way to force Hammer to error-out on Hammer.check_rate/3.
  # This is tricky because we don't configure multiple backends,
  # so the easiest (and naive) way to do it, without mocking, is to
  # plant a hand-crafted ets entry that makes it throw an exception
  # when it gets to it. This should not affect any shared state tests
  # because the rogue entry is only stored for a specific key.
  # The drawback of doing this, the test will break if we
  # ever change the underlying Rate Limiting backend/implementation.
  defp break_hammer(site) do
    scale_ms = site.ingest_rate_limit_scale_seconds * 1_000
    rogue_key = site.domain
    our_key = GateKeeper.key(rogue_key)
    {_, key} = Hammer.Utils.stamp_key(our_key, scale_ms)
    true = :ets.insert(:hammer_ets_buckets, {key, 1, "TOTALLY-WRONG", "ABSOLUTELY-BREAKING"})
    {:ok, :broken}
  end

  defp start_test_cache(cache_name) do
    %{start: {m, f, a}} = Cache.child_spec(cache_name: cache_name)
    apply(m, f, a)
  end

  defp add_site_and_refresh_cache(cache_name, site_data) do
    site = insert(:site, site_data)
    Cache.refresh_updated_recently(cache_name: cache_name, force?: true)
    site
  end
end
