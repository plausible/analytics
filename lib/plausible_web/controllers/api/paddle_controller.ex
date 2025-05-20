defmodule PlausibleWeb.Api.PaddleController do
  use PlausibleWeb, :controller
  use Plausible.Repo
  require Logger

  plug :verify_signature when action in [:webhook]

  def webhook(conn, %{"alert_name" => "subscription_created"} = params) do
    Plausible.Billing.subscription_created(params)
    |> webhook_response(conn, params)
  end

  def webhook(conn, %{"alert_name" => "subscription_updated"} = params) do
    Plausible.Billing.subscription_updated(params)
    |> webhook_response(conn, params)
  end

  def webhook(conn, %{"alert_name" => "subscription_cancelled"} = params) do
    Plausible.Billing.subscription_cancelled(params)
    |> webhook_response(conn, params)
  end

  def webhook(conn, %{"alert_name" => "subscription_payment_succeeded"} = params) do
    Plausible.Billing.subscription_payment_succeeded(params)
    |> webhook_response(conn, params)
  end

  def webhook(conn, _params) do
    send_resp(conn, 404, "") |> halt
  end

  @default_currency_fallback :EUR

  def currency(conn, _params) do
    plan_id = get_currency_reference_plan_id()
    customer_ip = PlausibleWeb.RemoteIP.get(conn)

    result =
      Plausible.Cache.Adapter.fetch(:customer_currency, {plan_id, customer_ip}, fn ->
        case Plausible.Billing.PaddleApi.fetch_prices([plan_id], customer_ip) do
          {:ok, %{^plan_id => money}} ->
            {:ok, money.currency}

          error ->
            Sentry.capture_message("Failed to fetch currency reference plan",
              extra: %{error: inspect(error)}
            )

            {:error, :fetch_prices_failed}
        end
      end)

    case result do
      {:ok, currency} ->
        conn
        |> put_status(200)
        |> json(%{currency: Cldr.Currency.currency_for_code!(currency).narrow_symbol})

      {:error, :fetch_prices_failed} ->
        conn
        |> put_status(200)
        |> json(%{
          currency: Cldr.Currency.currency_for_code!(@default_currency_fallback).narrow_symbol
        })
    end
  end

  def verify_signature(conn, _opts) do
    signature = Base.decode64!(conn.params["p_signature"])

    msg =
      Map.delete(conn.params, "p_signature")
      |> Enum.map(fn {key, val} -> {key, "#{val}"} end)
      |> List.keysort(0)
      |> PhpSerializer.serialize()

    [key_entry] = :public_key.pem_decode(get_paddle_key())

    public_key = :public_key.pem_entry_decode(key_entry)

    if :public_key.verify(msg, :sha, signature, public_key) do
      conn
    else
      send_resp(conn, 400, "") |> halt
    end
  end

  @paddle_currency_reference_plan_id "857097"
  @paddle_sandbox_currency_reference_plan_id "63842"
  defp get_currency_reference_plan_id() do
    if Application.get_env(:plausible, :environment) == "staging" do
      @paddle_sandbox_currency_reference_plan_id
    else
      @paddle_currency_reference_plan_id
    end
  end

  @paddle_prod_key File.read!("priv/paddle.pem")
  @paddle_sandbox_key File.read!("priv/paddle_sandbox.pem")

  defp get_paddle_key() do
    if Application.get_env(:plausible, :environment) == "staging" do
      @paddle_sandbox_key
    else
      @paddle_prod_key
    end
  end

  defp webhook_response({:ok, _}, conn, _params) do
    json(conn, "")
  end

  defp webhook_response({:error, details}, conn, _params) do
    Logger.error("Error processing Paddle webhook: #{inspect(details)}")

    conn |> send_resp(400, "") |> halt
  end
end
