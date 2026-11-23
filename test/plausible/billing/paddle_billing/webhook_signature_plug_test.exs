defmodule Plausible.Billing.PaddleBilling.WebhookSignaturePlugTest do
  use ExUnit.Case, async: false
  use Plausible.TestUtils

  import ExUnit.CaptureLog

  alias Plausible.Billing.PaddleBilling.WebhookSignature

  @secret "pdl_ntfset_secret"
  @body ~s({"event_type":"subscription.created"})

  setup do
    patch_env(:paddle_billing, webhook_secret: @secret)
  end

  defp header(ts \\ System.system_time(:second)) do
    "ts=#{ts};h1=#{WebhookSignature.sign(@body, ts, @secret)}"
  end

  defp call(header, body \\ @body) do
    conn =
      :post
      |> Plug.Test.conn("/")
      |> Plug.Conn.put_private(:raw_body, body)

    conn =
      if header, do: Plug.Conn.put_req_header(conn, "paddle-signature", header), else: conn

    WebhookSignature.call(conn, [])
  end

  test "lets a correctly signed request through" do
    conn = call(header())

    refute conn.halted
    refute conn.state == :sent
  end

  test "responds with 400 and halts when the signature does not match the body" do
    log =
      capture_log(fn ->
        conn = call(header(), "{}")

        assert conn.halted
        assert conn.status == 400
      end)

    assert log =~ "Rejected Paddle Billing webhook: invalid_signature"
  end

  test "responds with 400 and halts when the signature header is missing" do
    log =
      capture_log(fn ->
        conn = call(nil)

        assert conn.halted
        assert conn.status == 400
      end)

    assert log =~ "Rejected Paddle Billing webhook: malformed_header"
  end

  test "responds with 400 and halts when the timestamp is too old" do
    log =
      capture_log(fn ->
        conn = call(header(System.system_time(:second) - 60))

        assert conn.halted
        assert conn.status == 400
      end)

    assert log =~ "Rejected Paddle Billing webhook: stale_timestamp"
  end

  test "responds with 400 and halts when the secret is not configured" do
    patch_env(:paddle_billing, webhook_secret: nil)

    log =
      capture_log(fn ->
        conn = call(header())

        assert conn.halted
        assert conn.status == 400
      end)

    assert log =~ "Rejected Paddle Billing webhook: missing_secret"
  end
end
