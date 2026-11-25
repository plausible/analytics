defmodule PlausibleWeb.Api.RateLimitTest do
  use ExUnit.Case, async: false
  use Plausible.TestUtils

  alias PlausibleWeb.Api.RateLimit

  # Rate limits are enforced in fixed time windows, so a reset might happen
  # during a test. A test that expects a refusal makes 2 * limit + 1 requests.
  # Then at least one request is refused, even if the counter resets.

  defp key, do: "api_request:test:#{System.unique_integer([:positive])}"

  describe "check_burst/1" do
    test "refuses a request over the burst limit" do
      patch_env(RateLimit,
        legacy_per_user_hourly_request_limit: 600,
        burst_request_limit: 1,
        burst_period_seconds: 10
      )

      key = key()

      check_results = for _ <- 1..3, do: RateLimit.check_burst(key)

      assert {:error, :rate_limit_burst} in check_results
    end

    test "does not spend the hourly limit" do
      key = key()

      RateLimit.check_burst(key)

      assert RateLimit.check_burst_and_hourly(key, 1) == :ok
    end
  end

  describe "check_burst_and_hourly/2" do
    test "refuses a request over the hourly limit" do
      key = key()

      check_results = for _ <- 1..3, do: RateLimit.check_burst_and_hourly(key, 1)

      assert {:error, :rate_limit_hourly} in check_results
    end

    test "refuses a request over the burst limit" do
      patch_env(RateLimit,
        legacy_per_user_hourly_request_limit: 600,
        burst_request_limit: 1,
        burst_period_seconds: 10
      )

      key = key()

      check_results = for _ <- 1..3, do: RateLimit.check_burst_and_hourly(key, 100)

      assert {:error, :rate_limit_burst} in check_results
    end
  end
end
