defmodule Plausible.Mailer do
  use Bamboo.Mailer, otp_app: :plausible
  require Logger

  @type result() :: :ok | {:error, :hard_bounce} | {:error, :unknown_error}

  @spec send(Bamboo.Email.t()) :: result()
  def send(email) do
    case deliver_now(email) do
      {:ok, _email} -> :ok
      {:ok, _email, _response} -> :ok
      {:error, error} -> handle_error(error)
    end
  end

  defp handle_error(%{response: response}) when is_binary(response) do
    case Jason.decode(response) do
      {:ok, %{"ErrorCode" => 406}} ->
        {:error, :hard_bounce}

      {:ok, response} ->
        Logger.error("Failed to send e-mail", sentry: %{extra: %{response: inspect(response)}})
        {:error, :unknown_error}

      {:error, _any} ->
        Logger.error("Failed to send e-mail", sentry: %{extra: %{response: inspect(response)}})
        {:error, :unknown_error}
    end
  end

  defp handle_error(error) do
    Logger.error("Failed to send e-mail", sentry: %{extra: %{response: inspect(error)}})
    {:error, :unknown_error}
  end
end
