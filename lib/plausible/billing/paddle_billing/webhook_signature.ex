defmodule Plausible.Billing.PaddleBilling.WebhookSignature do
  @moduledoc """
  Verifies the `Paddle-Signature` header of Paddle Billing webhooks.

  The header looks like `ts=1671552777;h1=<hex>`. The signature is an
  HMAC-SHA256 of `"<ts>:<raw body>"` with the notification destination's secret.
  The header can carry more than one `h1` while the secret is being rotated.

  See https://developer.paddle.com/webhooks/signature-verification
  """

  @tolerance_seconds 5

  @type error() ::
          :missing_secret
          | :malformed_header
          | :invalid_signature
          | :stale_timestamp
          | :future_timestamp

  @spec verify(binary(), binary() | nil, binary() | nil, keyword()) :: :ok | {:error, error()}
  def verify(raw_body, header, secret, opts \\ [])

  def verify(_raw_body, _header, secret, _opts) when secret in [nil, ""],
    do: {:error, :missing_secret}

  def verify(raw_body, header, secret, opts) do
    now = Keyword.get_lazy(opts, :now, fn -> System.system_time(:second) end)

    with {:ok, ts, signatures} <- parse_header(header),
         :ok <- check_signature(raw_body, ts, signatures, secret) do
      check_timestamp(ts, now)
    end
  end

  @spec sign(binary(), integer(), binary()) :: binary()
  def sign(raw_body, ts, secret) do
    :hmac
    |> :crypto.mac(:sha256, secret, "#{ts}:#{raw_body}")
    |> Base.encode16(case: :lower)
  end

  defp parse_header(header) when is_binary(header) do
    parts =
      header
      |> String.downcase()
      |> String.trim()
      |> String.split(";")

    pairs =
      for part <- parts,
          [key, value] when key in ["ts", "h1"] <- [String.split(part, "=", parts: 2)],
          do: {key, value}

    with {_, ts} <- List.keyfind(pairs, "ts", 0),
         {ts, ""} <- Integer.parse(ts),
         [_ | _] = signatures <-
           for({"h1", s} <- pairs, s =~ ~r/\A[0-9a-f]{64}\z/, do: s) do
      {:ok, ts, signatures}
    else
      _ -> {:error, :malformed_header}
    end
  end

  defp parse_header(_), do: {:error, :malformed_header}

  defp check_signature(raw_body, ts, signatures, secret) do
    expected = sign(raw_body, ts, secret)

    if Enum.any?(signatures, &Plug.Crypto.secure_compare(&1, expected)) do
      :ok
    else
      {:error, :invalid_signature}
    end
  end

  defp check_timestamp(ts, now) do
    cond do
      ts < now - @tolerance_seconds -> {:error, :stale_timestamp}
      ts > now + @tolerance_seconds -> {:error, :future_timestamp}
      true -> :ok
    end
  end
end
