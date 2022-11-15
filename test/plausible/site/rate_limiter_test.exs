defmodule Plausible.Site.RateLimiterTest do
  use Plausible.DataCase, async: true

  alias Plausible.Site.Cache
  alias Plausible.Site.RateLimiter

  import ExUnit.CaptureLog

  test "(for now) throws an exception when cache is disabled" do
    assert_raise(RuntimeError, fn -> RateLimiter.policy("example.com") end)
  end

  test "sites not found in cache/DB are denied", %{test: test} do
    {:ok, _} = start_test_cache(test)
    opts = [cache_opts: [cache_name: test, force?: true]]
    assert :deny == RateLimiter.policy("example.com", opts)
  end

  test "site from cache with no ingest_rate_limit_threshold is allowed", %{test: test} do
    {:ok, _} = start_test_cache(test)
    opts = [cache_opts: [cache_name: test, force?: true]]
    domain = "site1.example.com"

    add_site_and_refresh_cache(test, domain: domain)

    assert :allow == RateLimiter.policy(domain, opts)
  end

  test "site from DB with no ingest_rate_limit_threshold is allowed", %{test: test} do
    {:ok, _} = start_test_cache(test)
    opts = [cache_opts: [cache_name: test, force?: true]]
    domain = "site1.example.com"

    insert(:site, domain: domain)

    assert :allow == RateLimiter.policy(domain, opts)
  end

  test "rate limiting works with threshold", %{test: test} do
    {:ok, _} = start_test_cache(test)
    opts = [cache_opts: [cache_name: test, force?: true]]
    domain = "site1.example.com"

    add_site_and_refresh_cache(test,
      domain: domain,
      ingest_rate_limit_threshold: 1,
      ingest_rate_limit_scale_seconds: 60
    )

    assert :allow == RateLimiter.policy(domain, opts)
    assert :deny == RateLimiter.policy(domain, opts)
    assert :deny == RateLimiter.policy(domain, opts)
  end

  test "rate limiting works with scale window", %{test: test} do
    {:ok, _} = start_test_cache(test)
    opts = [cache_opts: [cache_name: test, force?: true]]
    domain = "site1.example.com"

    add_site_and_refresh_cache(test,
      domain: domain,
      ingest_rate_limit_threshold: 1,
      ingest_rate_limit_scale_seconds: 1
    )

    assert :allow == RateLimiter.policy(domain, opts)
    Process.sleep(1)
    assert :deny == RateLimiter.policy(domain, opts)
    Process.sleep(1_000)
    assert :allow == RateLimiter.policy(domain, opts)
  end

  test "rate limiting prioritises cache lookups", %{test: test} do
    {:ok, _} = start_test_cache(test)
    cache_opts = [cache_name: test, force?: true]
    opts = [cache_opts: cache_opts]
    domain = "site1.example.com"

    site =
      add_site_and_refresh_cache(test,
        domain: domain,
        ingest_rate_limit_threshold: 1000,
        ingest_rate_limit_scale_seconds: 600
      )

    {:ok, _} = Plausible.Repo.delete(site)

    assert :allow == RateLimiter.policy(domain, opts)
    :ok = Cache.prefill(cache_opts)
    assert :deny == RateLimiter.policy(domain, opts)
  end

  test "rate limiter policy switches to allow when RL backend errors bubble-up", %{test: test} do
    {:ok, _} = start_test_cache(test)
    opts = [cache_opts: [cache_name: test, force?: true]]
    domain = "causingerrors.example.com"

    site =
      add_site_and_refresh_cache(test,
        domain: domain,
        ingest_rate_limit_threshold: 0,
        ingest_rate_limit_scale_seconds: 600
      )

    assert :deny == RateLimiter.policy(domain, opts)
    {:ok, :broken} = break_hammer(site)

    log =
      capture_log(fn ->
        assert :allow == RateLimiter.policy(domain, opts)
      end)

    assert log =~ "Error checking rate limit for 'ingest:site:causingerrors.example.com'"
    assert log =~ "Falling back to: allow"
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
    our_key = RateLimiter.key(rogue_key)
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
    Cache.refresh_one(site.domain, cache_name: cache_name, force?: true)
    site
  end
end
