defmodule Plausible.Billing.PaddleBilling.WebhookSignatureTest do
  use ExUnit.Case, async: true

  alias Plausible.Billing.PaddleBilling.WebhookSignature

  @secret "pdl_ntfset_secret"
  @body ~s({"event_type":"subscription.created"})
  @now 1_700_000_000

  defp header(ts \\ @now, body \\ @body, secret \\ @secret) do
    "ts=#{ts};h1=#{WebhookSignature.sign(body, ts, secret)}"
  end

  defp verify(header, opts \\ []) do
    WebhookSignature.verify(@body, header, Keyword.get(opts, :secret, @secret), now: @now)
  end

  test "accepts a correct signature" do
    assert :ok = verify(header())
  end

  test "matches Paddle's documented scheme" do
    expected =
      :crypto.mac(:hmac, :sha256, @secret, "#{@now}:#{@body}") |> Base.encode16(case: :lower)

    assert :ok = verify("ts=#{@now};h1=#{expected}")
  end

  test "rejects a signature of a different body" do
    assert {:error, :invalid_signature} = verify(header(@now, "{}"))
  end

  test "rejects a signature made with a different secret" do
    assert {:error, :invalid_signature} = verify(header(@now, @body, "other"))
  end

  test "rejects a timestamp that was altered after signing" do
    [_, h1] = String.split(header(), ";")
    assert {:error, :invalid_signature} = verify("ts=#{@now + 1};#{h1}")
  end

  test "accepts an uppercase signature" do
    [ts, h1] = String.split(header(), ";")
    ["h1", digest] = String.split(h1, "=")
    assert :ok = verify("#{ts};h1=#{String.upcase(digest)}")
  end

  test "accepts any of several signatures (secret rotation)" do
    [ts, h1] = String.split(header(), ";")
    assert :ok = verify("#{ts};h1=#{String.duplicate("a", 64)};#{h1}")
  end

  test "rejects more than two signatures" do
    [ts, h1] = String.split(header(), ";")
    other = "h1=#{String.duplicate("a", 64)}"
    assert :ok = verify("#{ts};#{other};#{h1}")
    assert {:error, :malformed_header} = verify("#{ts};#{other};#{other};#{h1}")
  end

  test "rejects a timestamp outside the tolerance, in both directions" do
    assert {:error, :stale_timestamp} = verify(header(@now - 6))
    assert {:error, :future_timestamp} = verify(header(@now + 6))
    assert :ok = verify(header(@now - 5))
  end

  test "rejects malformed or missing headers" do
    short = "ts=#{@now};h1=ff"
    non_hex = "ts=#{@now};h1=#{String.duplicate("z", 64)}"

    for header <- [nil, "", "garbage", "ts=abc;h1=ff", "h1=ff", "ts=#{@now}", short, non_hex] do
      assert {:error, :malformed_header} = verify(header)
    end
  end

  test "rejects everything when no secret is configured" do
    assert {:error, :missing_secret} = verify(header(), secret: nil)
    assert {:error, :missing_secret} = verify(header(), secret: "")
  end
end
