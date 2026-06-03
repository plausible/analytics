defmodule Plausible.DataMigration.OverwriteTotpSecret do
  @moduledoc """
  Overwrite `user.totp_secret` with the contents of `user.totp_secret_fallback`
  with vaulted values decoded and encoded again.
  """

  import Ecto.Query

  alias Plausible.Repo

  @confirmation_phrase "OVERWRITE TOTP_SECRET WITH TOTP_SECRET_FALLBACK"

  def run(opts \\ []) do
    IO.puts("""
    **!!!IMPORTANT!!!**: Please make sure you are following a proper
    rotation procedure!

    1. Set TOTP_VAULT_KEY_FALLBACK to the same value as TOTP_VAULT_KEY
    2. Run: DataMigration.BackfillTotpSecretFallback(dry_run?: false)
    3. Set TOTP_VAULT_KEY to a new value
    4. Run: DataMigration.OverwriteTotpSecret(dry_run?: false) <== YOU ARE HERE
    5. Set TOTP_VAULT_KEY_FALLBACK to a new random value

    **!!!WARNING!!!**: This is might lead to valid TOTP keys loss!
    Please make sure you have a new TOTP_VAULT_KEY set and that 
    TOTP_VAULT_KEY_FALLBACK was set to the current value of
    TOTP_VAULT_KEY and that the preceding backfill of 
    `totp_secret_fallback` completed successfully.

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
          where: not is_nil(u.totp_secret_fallback)
      )

    users_count = length(users)

    IO.puts("Overwriting totp_secret with totp_secret_fallback for #{users_count} users...")

    users
    |> Enum.with_index(1)
    |> Enum.each(fn {user, index} ->
      IO.puts("Overwriting totp_secret for user #{user.id} (#{index}/#{users_count})...")

      if not dry_run? do
        user
        |> Ecto.Changeset.change(totp_secret: user.totp_secret_fallback)
        |> Repo.update!()
      end
    end)

    IO.puts(
      "Finished overwriting totp_secret with totp_secret_fallback for #{users_count} users."
    )
  end
end
