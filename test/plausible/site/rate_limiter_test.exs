defmodule Plausible.Site.RateLimiterTest do
  use Plausible.DataCase, async: true

  alias Plausible.Site.Cache
  alias Plausible.Site.RateLimiter

  import ExUnit.CaptureLog

  setup %{test: test} do
    {:ok, _} = start_test_cache(test)
    opts = [cache_opts: [cache_name: test, force?: true]]
    {:ok, %{opts: opts}}
  end

  test "(for now) throws an exception when cache is disabled" do
    assert_raise(RuntimeError, fn -> RateLimiter.allow?("example.com") end)
  end

  test "sites not found in cache/DB are denied", %{opts: opts} do
    refute RateLimiter.allow?("example.com", opts)
  end

  test "site from cache with no ingest_rate_limit_threshold is allowed", %{test: test, opts: opts} do
    domain = "site1.example.com"

    add_site_and_refresh_cache(test, domain: domain)
    assert RateLimiter.allow?(domain, opts)
  end

  test "site from DB with no ingest_rate_limit_threshold is allowed", %{opts: opts} do
    domain = "site1.example.com"

    insert(:site, domain: domain)

    assert RateLimiter.allow?(domain, opts)
  end

  test "rate limiting works with threshold", %{test: test, opts: opts} do
    domain = "site1.example.com"

    add_site_and_refresh_cache(test,
      domain: domain,
      ingest_rate_limit_threshold: 1,
      ingest_rate_limit_scale_seconds: 60
    )

    assert RateLimiter.allow?(domain, opts)
    refute RateLimiter.allow?(domain, opts)
    refute RateLimiter.allow?(domain, opts)
  end

  test "rate limiting works with scale window", %{test: test, opts: opts} do
    domain = "site1.example.com"

    add_site_and_refresh_cache(test,
      domain: domain,
      ingest_rate_limit_threshold: 1,
      ingest_rate_limit_scale_seconds: 1
    )

    assert RateLimiter.allow?(domain, opts)
    Process.sleep(1)
    refute RateLimiter.allow?(domain, opts)
    Process.sleep(1_000)
    assert RateLimiter.allow?(domain, opts)
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

    assert RateLimiter.allow?(domain, opts)
    :ok = Cache.refresh_all(opts[:cache_opts])
    refute RateLimiter.allow?(domain, opts)
  end

  test "rate limiter policy switches to allow when RL backend errors bubble-up", %{
    test: test,
    opts: opts
  } do
    domain = "causingerrors.example.com"

    site =
      add_site_and_refresh_cache(test,
        domain: domain,
        ingest_rate_limit_threshold: 0,
        ingest_rate_limit_scale_seconds: 600
      )

    refute RateLimiter.allow?(domain, opts)
    {:ok, :broken} = break_hammer(site)

    log =
      capture_log(fn ->
        assert RateLimiter.allow?(domain, opts)
      end)

    assert log =~ "Error checking rate limit for 'ingest:site:causingerrors.example.com'"
    assert log =~ "Falling back to: allow"
  end

  test "telemetry event is emitted on :deny", %{test: test, opts: opts} do
    start_telemetry_handler(test, event: RateLimiter.policy_telemetry_event(:deny))
    RateLimiter.allow?("example.com", opts)
    assert_receive :telemetry_handled
  end

  test "telemetry event is emitted on :allow", %{test: test, opts: opts} do
    start_telemetry_handler(test, event: RateLimiter.policy_telemetry_event(:allow))

    domain = "site1.example.com"
    add_site_and_refresh_cache(test, domain: domain)

    RateLimiter.allow?(domain, opts)
    assert_receive :telemetry_handled
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

  defp start_telemetry_handler(test, event: event) do
    test_pid = self()

    :telemetry.attach(
      "#{test}-telemetry-handler",
      event,
      fn ^event, %{}, %{}, _ ->
        send(test_pid, :telemetry_handled)
      end,
      %{}
    )
  end
end
