defmodule Plausible.Auth.TOTP.RotationTest do
  use Plausible.DataCase, async: false

  import ExUnit.CaptureIO

  alias Plausible.Auth.TOTP
  alias Plausible.Auth.TOTP.FallbackVault
  alias Plausible.Auth.TOTP.Vault
  alias Plausible.DataMigration.BackfillTotpSecretFallback
  alias Plausible.DataMigration.OverwriteTotpSecret
  alias Plausible.Repo

  test "run full TOTP vault key rotation scenario" do
    Plausible.Test.Support.Sentry.setup(self())

    old_fallback_key = :crypto.strong_rand_bytes(32)
    old_key = :crypto.strong_rand_bytes(32)
    new_key = :crypto.strong_rand_bytes(32)

    # set a different vault key without restarting the whole app
    {:ok, config} = Vault.init(key: old_key)
    :sys.replace_state(Vault, fn _ -> config end)
    GenServer.call(Vault, :save_config)

    {:ok, config} = FallbackVault.init(key: old_fallback_key)
    :sys.replace_state(FallbackVault, fn _ -> config end)
    GenServer.call(FallbackVault, :save_config)

    # user with empty fallback key
    user_with_totp_legacy =
      insert(:user)
      |> TOTP.initiate()
      |> elem(1)
      |> TOTP.enable(:skip_verify)
      |> elem(1)
      |> Ecto.Changeset.change(totp_secret_fallback: nil)
      |> Repo.update!()

    # user with both keys set to old key initially
    user_with_totp =
      insert(:user)
      |> TOTP.initiate()
      |> elem(1)
      |> TOTP.enable(:skip_verify)
      |> elem(1)

    user_without_totp = insert(:user)

    # generate 2FA codes for further testing (with reuse)
    code_legacy = NimbleTOTP.verification_code(user_with_totp_legacy.totp_secret)
    code = NimbleTOTP.verification_code(user_with_totp.totp_secret)

    # ensure verification works with fallback secret empty
    assert {:ok, user_with_totp_legacy} =
             TOTP.validate_code(user_with_totp_legacy, code_legacy, allow_reuse?: true)

    assert [] = Sentry.Test.pop_sentry_reports()

    # set the existing key as the key for the fallback vault - first step of rotation
    {:ok, config} = FallbackVault.init(key: new_key)
    :sys.replace_state(FallbackVault, fn _ -> config end)
    GenServer.call(FallbackVault, :save_config)

    # run backfill of the fallback secrets - second step of rotation
    assert capture_io(
             [input: "BACKFILL TOTP_SECRET_FALLBACK WITH TOTP_SECRET", capture_prompt: false],
             fn ->
               BackfillTotpSecretFallback.run(dry_run?: false)
             end
           ) =~ "Finished backfilling totp_secret_fallback with totp_secret for 2 users."

    assert_matches %{
                     totp_secret: ^user_with_totp_legacy.totp_secret,
                     totp_secret_fallback: ^user_with_totp_legacy.totp_secret
                   } = Repo.reload!(user_with_totp_legacy)

    assert_matches %{
                     totp_secret: ^user_with_totp.totp_secret,
                     totp_secret_fallback: ^user_with_totp.totp_secret_fallback
                   } = Repo.reload!(user_with_totp)

    assert_matches %{
                     totp_secret: nil,
                     totp_secret_fallback: nil
                   } = Repo.reload!(user_without_totp)

    # set a new key for the main vault - third step of rotation
    {:ok, config} = Vault.init(key: new_key)
    :sys.replace_state(Vault, fn _ -> config end)
    GenServer.call(Vault, :save_config)

    # reload users to ensure they use "mangled" secret due to changed vault key
    user_with_totp_legacy = Repo.reload!(user_with_totp_legacy)
    user_with_totp = Repo.reload!(user_with_totp)

    assert {:ok, user_with_totp_legacy} =
             TOTP.validate_code(user_with_totp_legacy, code_legacy, allow_reuse?: true)

    assert [sentry_error] = Sentry.Test.pop_sentry_reports()
    assert sentry_error.message.formatted == "Failed to decode main totp secret"
    assert sentry_error.extra.user_id == user_with_totp_legacy.id

    assert {:ok, user_with_totp} = TOTP.validate_code(user_with_totp, code, allow_reuse?: true)

    assert [sentry_error] = Sentry.Test.pop_sentry_reports()
    assert sentry_error.message.formatted == "Failed to decode main totp secret"
    assert sentry_error.extra.user_id == user_with_totp.id

    # run overwrite - fourth step of rotation
    assert capture_io(
             [input: "OVERWRITE TOTP_SECRET WITH TOTP_SECRET_FALLBACK", capture_prompt: false],
             fn ->
               OverwriteTotpSecret.run(dry_run?: false)
             end
           ) =~ "Finished overwriting totp_secret with totp_secret_fallback for 2 users."

    # verify that main secret works now
    user_with_totp_legacy = Repo.reload!(user_with_totp_legacy)
    user_with_totp = Repo.reload!(user_with_totp)

    assert {:ok, user_with_totp_legacy} =
             TOTP.validate_code(user_with_totp_legacy, code_legacy, allow_reuse?: true)

    assert [] = Sentry.Test.pop_sentry_reports()

    assert {:ok, user_with_totp} = TOTP.validate_code(user_with_totp, code, allow_reuse?: true)

    assert [] = Sentry.Test.pop_sentry_reports()

    # set fallback vault key to a random new value - fifth step of rotation
    {:ok, config} = FallbackVault.init(key: :crypto.strong_rand_bytes(32))
    :sys.replace_state(FallbackVault, fn _ -> config end)
    GenServer.call(FallbackVault, :save_config)

    # verify that everything still works
    user_with_totp_legacy = Repo.reload!(user_with_totp_legacy)
    user_with_totp = Repo.reload!(user_with_totp)

    assert {:ok, _user_with_totp_legacy} =
             TOTP.validate_code(user_with_totp_legacy, code_legacy, allow_reuse?: true)

    assert [] = Sentry.Test.pop_sentry_reports()

    assert {:ok, _user_with_totp} = TOTP.validate_code(user_with_totp, code, allow_reuse?: true)

    assert [] = Sentry.Test.pop_sentry_reports()
  end
end
