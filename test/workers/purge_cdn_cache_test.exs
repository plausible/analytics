defmodule Plausible.Workers.PurgeCDNCacheTest do
  use Plausible.DataCase, async: true
  import ExUnit.CaptureLog
  import Plug.Conn

  alias Plausible.Workers.PurgeCDNCache

  describe "perform/1" do
    setup do
      # Set test configuration
      Application.put_env(:plausible, Plausible.Workers.PurgeCDNCache,
        pullzone_id: "456",
        api_key: "test-api-key",
        req_opts: [
          plug: {Req.Test, Plausible.Workers.PurgeCDNCache}
        ]
      )

      :ok
    end

    test "successfully purges cache" do
      Req.Test.expect(Plausible.Workers.PurgeCDNCache, &send_resp(&1, 204, "ok"))

      assert {:ok, :success} = PurgeCDNCache.perform(%Oban.Job{args: %{"id" => "adf"}})
    end

    test "handles missing configuration" do
      # Clear configuration
      Application.put_env(:plausible, Plausible.Workers.PurgeCDNCache, [])

      {result, log} =
        with_log(fn -> PurgeCDNCache.perform(%Oban.Job{args: %{"id" => "adf"}}) end)

      assert {:discard, "Configuration missing"} = result
      assert log =~ "Ignoring purge CDN cache for tracker script adf: Configuration missing"
    end

    test "handles unexpected status code" do
      Req.Test.expect(
        Plausible.Workers.PurgeCDNCache,
        &send_resp(&1, 500, "internal server error")
      )

      {result, log} =
        with_log(fn -> PurgeCDNCache.perform(%Oban.Job{args: %{"id" => "adf"}}) end)

      assert {:error, "Unexpected status: 500"} = result
      assert log =~ "Failed to purge CDN cache for tracker script adf: Unexpected status: 500"
    end

    test "handles network errors" do
      Req.Test.expect(
        Plausible.Workers.PurgeCDNCache,
        &Req.Test.transport_error(&1, :econnrefused)
      )

      {result, log} =
        with_log(fn -> PurgeCDNCache.perform(%Oban.Job{args: %{"id" => "adf"}}) end)

      assert {:error, %Req.TransportError{reason: :econnrefused}} = result

      assert log =~
               "Failed to purge CDN cache for tracker script adf: %Req.TransportError{reason: :econnrefused}"
    end
  end

  describe "backoff/1" do
    test "implements exponential backoff starting at 3 minutes" do
      assert PurgeCDNCache.backoff(%Oban.Job{attempt: 1}) == 180
      assert PurgeCDNCache.backoff(%Oban.Job{attempt: 2}) == 360
      assert PurgeCDNCache.backoff(%Oban.Job{attempt: 3}) == 720
      assert PurgeCDNCache.backoff(%Oban.Job{attempt: 4}) == 1440
      assert PurgeCDNCache.backoff(%Oban.Job{attempt: 5}) == 2880
    end
  end
end
