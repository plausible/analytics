defmodule Plausible.Mailer do
  use Bamboo.Mailer, otp_app: :plausible
  use Plausible
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
        maybe_record_rejected_send(e)

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

  defp maybe_record_rejected_send(exception)

  on_ce do
    defp maybe_record_rejected_send(_exception), do: :ok
  end

  on_ee do
    defp maybe_record_rejected_send(%Bamboo.PostmarkAdapter.Error{} = e) do
      if Bamboo.PostmarkAdapter.Error.is_hard_bounce(e) do
        Plausible.EmailSuppressions.create_from_rejected_send(%{
          email: sole_recipient(e.email),
          details: "Rejected by Postmark on send: #{inspect(e.reason)}"
        })
      end

      :ok
    end

    defp maybe_record_rejected_send(_exception), do: :ok
  end

  defp suppressed_recipients(email)

  on_ce do
    defp suppressed_recipients(_email) do
      # trick the type checker
      if always(true), do: [], else: ["unreachable"]
    end
  end

  on_ee do
    defp suppressed_recipients(email) do
      address = sole_recipient(email)

      cond do
        # Priority-stream mail (password resets, 2FA, e-mail verification)
        # has to go through even to an address we'd otherwise suppress -
        # refusing it could lock someone out of their own account.
        priority_stream?(email) ->
          []

        Plausible.EmailSuppressions.suppressed?(address) ->
          [address]

        true ->
          []
      end
    end

    defp sole_recipient(email) do
      case Bamboo.Mailer.normalize_addresses(email).to do
        [{_name, address}] ->
          address

        to ->
          # this can be handled in the future, but currently isn't ever used
          raise "Plausible.Mailer only supports a single `to` recipient, got: #{inspect(to)}"
      end
    end

    defp priority_stream?(email) do
      get_in(email.private, [:message_params, "MessageStream"]) == "priority"
    end
  end
end
