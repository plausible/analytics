defmodule Plausible.Mailer do
  use Bamboo.Mailer, otp_app: :plausible

  @spec send(Bamboo.Email.t()) :: :ok | {:error, :hard_bounce} | {:error, :unknown_error}
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
        Sentry.capture_message("Failed to send e-mail", extra: %{response: response})
        {:error, :unknown_error}

      {:error, _any} ->
        Sentry.capture_message("Failed to send e-mail", extra: %{response: response})
        {:error, :unknown_error}
    end
  end

  defp handle_error(error) do
    Sentry.capture_message("Failed to send e-mail", extra: %{response: error})
    {:error, :unknown_error}
  end
end
