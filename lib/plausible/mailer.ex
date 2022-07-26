defmodule Plausible.Mailer do
  use Bamboo.Mailer, otp_app: :plausible

  def send_email(email), do: do_send_email(email)
  def send_email_safe(email), do: do_send_email(email)

  defp do_send_email(email) do
    case Plausible.Mailer.deliver_now(email) do
      {:ok, email} -> email
      {:error, error} -> handle_error(error)
    end
  end

  defp handle_error(%Bamboo.ApiError{message: message} = error) do
    case Jason.decode!(message.response) do
      %{"ErrorCode" => 406} ->
        {:error, error}

      response ->
        Sentry.capture_exception(response, extra: %{extra: "Error while sending email"})
        {:error, error}
    end
  end
end
