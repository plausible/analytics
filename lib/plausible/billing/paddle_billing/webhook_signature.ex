defmodule Plausible.Billing.PaddleBilling.WebhookSignature do
  @moduledoc """
  Verifies the `Paddle-Signature` header of Paddle Billing webhooks.

  The header looks like `ts=1671552777;h1=<hex>`. The signature is an
  HMAC-SHA256 of `"<ts>:<raw body>"` with the notification destination's secret.
  The header can carry up to two `h1` values while the secret is being rotated.

  Used as a plug, it responds with 400 and halts when the request signature
  is invalid.

  See https://developer.paddle.com/webhooks/signature-verification
  """

  @behaviour Plug

  require Logger

  import Plug.Conn

  alias Plausible.Billing.PaddleBilling

  @tolerance_seconds 5

  @type error() ::
          :missing_secret
          | :malformed_header
          | :invalid_signature
          | :stale_timestamp
          | :future_timestamp

  @impl Plug
  def init(opts), do: opts

  @impl Plug
  def call(conn, _opts) do
    signature = conn |> get_req_header("paddle-signature") |> List.first()

    case verify(
           PlausibleWeb.RawBodyReader.raw_body(conn),
           signature,
           PaddleBilling.webhook_secret()
         ) do
      :ok ->
        conn

      {:error, reason} ->
        Logger.error("Rejected Paddle Billing webhook: #{reason}")
        conn |> send_resp(400, "") |> halt()
    end
  end

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
    raw_body |> digest(ts, secret) |> Base.encode16(case: :lower)
  end

  defp digest(raw_body, ts, secret) do
    :crypto.mac(:hmac, :sha256, secret, "#{ts}:#{raw_body}")
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
         signatures when length(signatures) in 1..2 <- for({"h1", s} <- pairs, do: s),
         digests = Enum.map(signatures, &decode_digest/1),
         true <- Enum.all?(digests) do
      {:ok, ts, digests}
    else
      _ -> {:error, :malformed_header}
    end
  end

  defp parse_header(_), do: {:error, :malformed_header}

  defp decode_digest(<<hex::binary-size(64)>>) do
    case Base.decode16(hex, case: :lower) do
      {:ok, <<_::binary-size(32)>> = digest} -> digest
      _ -> nil
    end
  end

  defp decode_digest(_), do: nil

  defp check_signature(raw_body, ts, digests, secret) do
    expected = digest(raw_body, ts, secret)

    if Enum.any?(digests, &Plug.Crypto.secure_compare(&1, expected)) do
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
