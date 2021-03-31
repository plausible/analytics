defmodule PlausibleWeb.Api.PaddleController do
  use PlausibleWeb, :controller
  use Plausible.Repo
  require Logger

  plug :verify_signature

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

  @paddle_key File.read!("priv/paddle.pem")

  def verify_signature(conn, _opts) do
    signature = Base.decode64!(conn.params["p_signature"])

    msg =
      Map.delete(conn.params, "p_signature")
      |> Enum.map(fn {key, val} -> {key, "#{val}"} end)
      |> List.keysort(0)
      |> PhpSerializer.serialize()

    [key_entry] = :public_key.pem_decode(@paddle_key)
    public_key = :public_key.pem_entry_decode(key_entry)

    if :public_key.verify(msg, :sha, signature, public_key) do
      conn
    else
      send_resp(conn, 400, "") |> halt
    end
  end

  def verified_signature?(params) do
    signature = Base.decode64!(params["p_signature"])

    msg =
      Map.delete(params, "p_signature")
      |> Enum.map(fn {key, val} -> {key, "#{val}"} end)
      |> List.keysort(0)
      |> PhpSerializer.serialize()

    [key_entry] = :public_key.pem_decode(@paddle_key)
    public_key = :public_key.pem_entry_decode(key_entry)
    :public_key.verify(msg, :sha, signature, public_key)
  end

  defp webhook_response({:ok, _}, conn, _params) do
    json(conn, "")
  end

  defp webhook_response({:error, changeset}, conn, _params) do
    Logger.error("Error processing Paddle webhook: #{inspect(changeset)}")

    conn |> send_resp(400, "") |> halt
  end
end
