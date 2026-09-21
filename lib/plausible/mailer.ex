defmodule Plausible.Mailer do
  use Bamboo.Mailer, otp_app: :plausible
  require Logger

  @spec send(Bamboo.Email.t()) :: :ok | {:error, :unknown_error}
  def send(email) do
    try do
      deliver_now!(email)
    rescue
      e ->
        # this message is ignored by Sentry, only appears in logs
        log = "Failed to send e-mail:\n\n  " <> Exception.format(:error, e, __STACKTRACE__)
        # Sentry report is built entirely from crash_reason
        crash_reason = {e, __STACKTRACE__}

        Logger.error(log, crash_reason: crash_reason)
        {:error, :unknown_error}
    else
      _sent_email -> :ok
    end
  end
end
