defmodule Plausible.DataMigration.BackfillTotpSecretFallback do
  @moduledoc """
  Backfill `user.totp_secret_fallback` with the contents of `user.totp_secret`
  with vaulted values decoded and encoded again.
  """

  import Ecto.Query

  alias Plausible.Repo

  @confirmation_phrase "BACKFILL TOTP_SECRET_FALLBACK WITH TOTP_SECRET"

  def run(opts \\ []) do
    IO.puts("""
    **!!!IMPORTANT!!!**: Please make sure you are following a proper
    rotation procedure!

    1. Set TOTP_VAULT_KEY_FALLBACK to the same value as TOTP_VAULT_KEY
    2. Run: DataMigration.BackfillTotpSecretFallback(dry_run?: false) <== YOU ARE HERE
    3. Set TOTP_VAULT_KEY to a new value
    4. Run: DataMigration.OverwriteTotpSecret(dry_run?: false)
    5. Set TOTP_VAULT_KEY_FALLBACK to a new random value

    **WARNING**: Please make sure that TOTP_VAULT_KEY_FALLBACK is set to
    the same value as TOTP_VAULT_KEY before running this script.

    To confirm that you know what you are doing, please type in:

    #{@confirmation_phrase}

    and hit Enter.

    """)

    confirmation = IO.gets("Confirmation: ")

    if String.trim(confirmation) == @confirmation_phrase do
      run_backfill(opts)
    else
      IO.puts("Wrong confirmation phrase. Aborting!")
      {:error, :aborted}
    end
  end

  defp run_backfill(opts) do
    dry_run? = Keyword.get(opts, :dry_run?, true)

    users =
      Repo.all(
        from u in Plausible.Auth.User,
          where: not is_nil(u.totp_secret)
      )

    users_count = length(users)

    IO.puts("Backfilling totp_secret_fallback with totp_secret for #{users_count} users...")

    users
    |> Enum.with_index(1)
    |> Enum.each(fn {user, index} ->
      IO.puts("Backfilling totp_secret_fallback for user #{user.id} (#{index}/#{users_count})...")

      if not dry_run? do
        user
        |> Ecto.Changeset.change(totp_secret_fallback: user.totp_secret)
        |> Repo.update!()
      end
    end)

    IO.puts(
      "Finished backfilling totp_secret_fallback with totp_secret for #{users_count} users."
    )
  end
end
