defmodule Plausible.Mailer do
  use Bamboo.Mailer, otp_app: :plausible

  def send_email(email) do
    try do
      Plausible.Mailer.deliver_now!(email)
    rescue
      error ->
        Sentry.capture_exception(error,
          stacktrace: __STACKTRACE__,
          extra: %{extra: "Error while sending email"}
        )

        reraise error, __STACKTRACE__
    end
  end

  def send_email_safe(email) do
    try do
      Plausible.Mailer.deliver_now!(email)
    rescue
      error ->
        Sentry.capture_exception(error,
          stacktrace: __STACKTRACE__,
          extra: %{extra: "Error while sending email"}
        )
    end
  end
end
