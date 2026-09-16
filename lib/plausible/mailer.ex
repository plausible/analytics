defmodule Plausible.Mailer do
  use Bamboo.Mailer, otp_app: :plausible
  require Logger

  @spec send(Bamboo.Email.t()) :: :ok | {:error, :unknown_error | :suppressed}
  def send(email) do
    case suppressed_recipients(email) do
      [] ->
        do_send(email)

      suppressed ->
        Logger.warning(
          "Not sending e-mail, recipient(s) are suppressed: #{Enum.join(suppressed, ", ")}"
        )

        {:error, :suppressed}
    end
  end

  defp do_send(email) do
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

  defp suppressed_recipients(email) do
    # to, cc/bcc can hold a raw string, a {name, address} tuple, or any
    # struct implementing `Bamboo.Formatter` (e.g. `Plausible.Auth.User`),
    # each possibly wrapped in a list.
    normalized = Bamboo.Mailer.normalize_addresses(email)

    [normalized.to, normalized.cc, normalized.bcc]
    |> List.flatten()
    |> Enum.map(fn {_name, address} -> address end)
    |> Enum.filter(&Plausible.EmailSuppressions.suppressed?/1)
  end
end
