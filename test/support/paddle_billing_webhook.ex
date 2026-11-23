defmodule Plausible.Billing.PaddleBilling.WebhookFixtures do
  @moduledoc """
  Builders of Paddle Billing webhook events and signed webhook requests.

  Events follow the payloads documented for `subscription.created` and
  `subscription.updated`, reduced to the fields we read.
  """

  use PlausibleWeb.VerifiedRoutes

  import Plug.Conn, only: [put_req_header: 3]

  alias Plausible.Billing.PaddleBilling
  alias Plausible.Billing.PaddleBilling.WebhookSignature

  @default_occurred_at "2026-11-10T10:00:00.000000Z"

  @doc """
  Builds an event. `overrides` replace top-level keys of the envelope, except
  `:data`, which is merged into the default subscription.
  """
  def subscription_event(event_type, overrides \\ []) do
    {data, overrides} = Keyword.pop(overrides, :data, %{})

    Map.merge(
      %{
        "event_id" => unique("evt"),
        "event_type" => event_type,
        "occurred_at" => @default_occurred_at,
        "notification_id" => unique("ntf"),
        "data" => Map.merge(subscription_data(), stringify(data))
      },
      stringify(Map.new(overrides))
    )
  end

  def subscription_data() do
    %{
      "id" => "sub_01hv8x29kz0t586xy6zn1a62ny",
      "status" => "active",
      "customer_id" => "ctm_01hv6y1jedq4p1n0yqn5ba3ky4",
      "currency_code" => "USD",
      "started_at" => "2026-11-10T10:00:00.000000Z",
      "first_billed_at" => "2026-11-10T10:00:00.000000Z",
      "next_billed_at" => "2026-12-10T10:00:00.000000Z",
      "paused_at" => nil,
      "canceled_at" => nil,
      "scheduled_change" => nil,
      "custom_data" => nil,
      "current_billing_period" => %{
        "starts_at" => "2026-11-10T10:00:00.000000Z",
        "ends_at" => "2026-12-10T10:00:00.000000Z"
      },
      "items" => [item()]
    }
  end

  def item(overrides \\ %{}) do
    Map.merge(
      %{
        "status" => "active",
        "quantity" => 1,
        "recurring" => true,
        "price" => %{
          "id" => "pri_01gsz8x8sawmvhz1pv30nge1ke",
          "product_id" => "pro_01gsz4t5hdjse780zja8vvr7jg",
          "unit_price" => %{"amount" => "3000", "currency_code" => "USD"},
          "unit_price_overrides" => [],
          "billing_cycle" => %{"interval" => "month", "frequency" => 1}
        }
      },
      overrides
    )
  end

  @doc """
  Posts an event the way Paddle does: raw JSON signed with the destination's
  secret. 

  Options: 

    * `:secret`, 
    * `:ts` (signature timestamp), 
    * `:signature_header` (replaces the header altogether, `nil` removes it), 
    * `:send_body` (sends this body instead of the signed one), 
    * `:pretty` (encodes the body with whitespace, to prove that the signature covers the raw bytes).
  """
  def post_signed(conn, event, opts \\ []) do
    body = Jason.encode!(event, pretty: Keyword.get(opts, :pretty, false))
    secret = Keyword.get_lazy(opts, :secret, &PaddleBilling.webhook_secret/0)
    ts = Keyword.get_lazy(opts, :ts, fn -> System.system_time(:second) end)

    header =
      Keyword.get_lazy(opts, :signature_header, fn ->
        "ts=#{ts};h1=#{WebhookSignature.sign(body, ts, secret)}"
      end)

    conn
    |> put_req_header("content-type", "application/json")
    |> maybe_put_header("paddle-signature", header)
    |> Phoenix.ConnTest.dispatch(
      PlausibleWeb.Endpoint,
      :post,
      ~p"/api/paddle-billing/webhook",
      Keyword.get(opts, :send_body, body)
    )
  end

  defp maybe_put_header(conn, _name, nil), do: conn
  defp maybe_put_header(conn, name, value), do: put_req_header(conn, name, value)

  defp unique(prefix), do: "#{prefix}_#{System.unique_integer([:positive])}"

  defp stringify(map), do: Map.new(map, fn {k, v} -> {to_string(k), v} end)
end
