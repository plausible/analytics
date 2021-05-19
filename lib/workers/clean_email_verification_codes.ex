defmodule Plausible.Workers.CleanEmailVerificationCodes do
  use Plausible.Repo
  use Oban.Worker, queue: :clean_email_verification_codes

  @impl Oban.Worker
  def perform(_job) do
    Repo.update_all(
      from(c in "email_verification_codes",
        where: not is_nil(c.user_id),
        where: c.issued_at < fragment("now() - INTERVAL '4 hours'")
      ),
      set: [user_id: nil]
    )

    :ok
  end
end
