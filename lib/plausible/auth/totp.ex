defmodule Plausible.Auth.TOTP do
  @moduledoc """
  TOTP auth context

  Handles all the aspects of TOTP setup, management and validation for users.

  ## Setup

  TOTP setup is started with `initiate/1`. At this stage, a random secret
  binary is generated for user and stored under `User.totp_secret`. The secret
  is additionally encrypted while stored in the database using `Cloak`. The
  vault for safe storage is configured in `Plausible.Auth.TOTP.Vault` via
  a dedicated `Ecto` type defined in `Plausible.Auth.TOTP.EncryptedBinary`.
  The function returns updated user along with TOTP URI and a readable form
  of secret. Both - the URI and readable secret - are meant for exposure
  in the user's setup screen. The URI should be encoded as a QR code.

  After initiation, user is expected to confirm valid setup with `enable/2`,
  providing TOTP code from their authenticator app. After code validation
  passes successfully, the `User.totp_enabled` flag is set to `true`.
  Finally, the user must be immediately presented with a list of recovery codes
  returned by the same call of `enable/2`. The codes should be presented
  in copy/paste friendly form, ideally also with a print-friendly view option.

  The `initiate/1` and `enable/1` functions can be safely called multiple
  times, allowing user to abort and restart setup up to these stages.

  ## Management

  The state of TOTP for a particular user can be chcecked by calling
  `enabled?/1` or `initiated?/1`.

  TOTP can be disabled with `disable/2`. User is expected to provide their
  current password for safety. Once disabled, all TOTP user settings are
  cleared and any remaining generated recovery codes are removed. The function
  can be safely run more than once. There's also alternative call for forced
  disabling of TOTP for a given user without sending any notification,
  `force_disable/1`. It's meant for use in situation where user lost both,
  2FA device and recovery codes and their identity is verified independently.

  If the user needs to regenerate the recovery codes outside of setup procedure,
  they must do it via `generate_recovery_codes/2`, providing their current
  password for safety. They must be warned that any existing recovery codes
  will be invalidated.

  ## Validation

  After logging in, user's TOTP state must be checked with `enabled?/1`.

  If enabled, user must be presented with TOTP code input form accepting
  6 digit characters. The code must be checked using `validate_code/2`.

  User must have an option to alternatively input one of their recovery
  codes. Those codes must be checked with `use_recovery_code/2`.

  ## Code validity

  In case of TOTP codes, a grace period of 30 seconds is applied, which
  allows user to use their current and previous TOTP code, assuming 30
  second validity window of each. This allows user to use code that was
  about to expire before the submission. Regardless of that, each TOTP
  code can be used only once. Validation procedure rejects repeat use
  of the same code for safety. It's done by tracking last time a TOTP
  code was used successfully, stored under `User.totp_last_used_at`.

  In case of recovery codes, each code is deleted immediately after use.
  They are strictly one-time use only.

  ## TOTP Token

  TOTP token is an alternate method of authenticating  user session.
  It's main use case is "trust this device" functionality, where user
  can decide to skip 2FA verification for a particular browser session
  for next N days. The token should then be stored in an encrypted,
  signed cookie with a proper expiration timestamp.

  The token should be reset each time it either fails to match
  or when other credentials (like password) are reset. This should
  effectively invalidate all trusted devices for a given user.

  """

  import Ecto.Changeset, only: [change: 2]
  import Ecto.Query, only: [from: 2]

  alias Plausible.Auth
  alias Plausible.Auth.TOTP
  alias Plausible.Repo
  alias PlausibleWeb.Email

  @recovery_codes_count 10

  @spec enabled?(Auth.User.t()) :: boolean()
  def enabled?(user) do
    user.totp_enabled and not is_nil(user.totp_secret)
  end

  @spec initiated?(Auth.User.t()) :: boolean()
  def initiated?(user) do
    not user.totp_enabled and not is_nil(user.totp_secret)
  end

  @spec initiate(Auth.User.t()) ::
          {:ok, Auth.User.t(), %{totp_uri: String.t(), secret: String.t()}}
          | {:error, :not_verified | :already_setup}
  def initiate(%{email_verified: false}) do
    {:error, :not_verified}
  end

  def initiate(%{totp_enabled: true}) do
    {:error, :already_setup}
  end

  def initiate(user) do
    secret = NimbleTOTP.secret()

    user =
      user
      |> change(
        totp_enabled: false,
        totp_secret: secret,
        totp_token: nil
      )
      |> Repo.update!()

    {:ok, user, %{totp_uri: totp_uri(user), secret: readable_secret(user)}}
  end

  @spec enable(Auth.User.t(), String.t() | :skip_verify, Keyword.t()) ::
          {:ok, Auth.User.t(), %{recovery_codes: [String.t()]}}
          | {:error, :invalid_code | :not_initiated}
  def enable(user, code, opts \\ [])

  def enable(%{totp_secret: nil}, _, _) do
    {:error, :not_initiated}
  end

  def enable(user, :skip_verify, _opts) do
    do_enable(user)
  end

  def enable(user, code, opts) do
    with {:ok, user} <- do_validate_code(user, code, opts) do
      do_enable(user)
    end
  end

  defp do_enable(user) do
    {:ok, {user, recovery_codes}} =
      Repo.transaction(fn ->
        user =
          user
          |> change(
            totp_enabled: true,
            totp_token: generate_token()
          )
          |> Repo.update!()

        {:ok, recovery_codes} = do_generate_recovery_codes(user)

        {user, recovery_codes}
      end)

    user
    |> Email.two_factor_enabled_email()
    |> Plausible.Mailer.send()

    {:ok, user, %{recovery_codes: recovery_codes}}
  end

  @spec disable(Auth.User.t(), String.t()) :: {:ok, Auth.User.t()} | {:error, :invalid_password}
  def disable(user, password) do
    if Auth.Password.match?(password, user.password_hash) do
      {:ok, user} = disable_for(user)

      user
      |> Email.two_factor_disabled_email()
      |> Plausible.Mailer.send()

      {:ok, user}
    else
      {:error, :invalid_password}
    end
  end

  @spec force_disable(Auth.User.t()) :: {:ok, Auth.User.t()}
  def force_disable(user) do
    disable_for(user)
  end

  @spec reset_token(Auth.User.t()) :: Auth.User.t()
  def reset_token(user) do
    new_token =
      if user.totp_enabled do
        generate_token()
      end

    user
    |> change(totp_token: new_token)
    |> Repo.update!()
  end

  @spec generate_recovery_codes(Auth.User.t(), String.t()) ::
          {:ok, [String.t()]} | {:error, :invalid_password | :not_enabled}
  def generate_recovery_codes(%{totp_enabled: false}) do
    {:error, :not_enabled}
  end

  def generate_recovery_codes(user, password) do
    if Auth.Password.match?(password, user.password_hash) do
      do_generate_recovery_codes(user)
    else
      {:error, :invalid_password}
    end
  end

  defp do_generate_recovery_codes(%{totp_enabled: false}) do
    {:error, :not_enabled}
  end

  defp do_generate_recovery_codes(user) do
    Repo.transaction(fn ->
      {_, _} =
        user
        |> recovery_codes_query()
        |> Repo.delete_all()

      plain_codes = TOTP.RecoveryCode.generate_codes(@recovery_codes_count)

      now =
        NaiveDateTime.utc_now()
        |> NaiveDateTime.truncate(:second)

      codes =
        plain_codes
        |> Enum.map(fn plain_code ->
          user
          |> TOTP.RecoveryCode.changeset(plain_code)
          |> TOTP.RecoveryCode.changeset_to_map(now)
        end)

      {_, _} = Repo.insert_all(TOTP.RecoveryCode, codes)

      plain_codes
    end)
  end

  @spec validate_code(Auth.User.t(), String.t(), Keyword.t()) ::
          {:ok, Auth.User.t()} | {:error, :invalid_code | :not_enabled}
  def validate_code(user, code, opts \\ [])

  def validate_code(%{totp_enabled: false}, _, _) do
    {:error, :not_enabled}
  end

  def validate_code(user, code, opts) do
    do_validate_code(user, code, opts)
  end

  @spec use_recovery_code(Auth.User.t(), String.t()) ::
          :ok | {:error, :invalid_code | :not_enabled}
  def use_recovery_code(%{totp_enabled: false}, _) do
    {:error, :not_enabled}
  end

  def use_recovery_code(user, code) do
    matching_code =
      user
      |> recovery_codes_query()
      |> Repo.all()
      |> Enum.find(&TOTP.RecoveryCode.match?(&1, code))

    if matching_code do
      Repo.delete!(matching_code)
      :ok
    else
      {:error, :invalid_code}
    end
  end

  defp disable_for(user) do
    Repo.transaction(fn ->
      {_, _} =
        user
        |> recovery_codes_query()
        |> Repo.delete_all()

      user
      |> change(
        totp_enabled: false,
        totp_token: nil,
        totp_secret: nil,
        totp_last_used_at: nil
      )
      |> Repo.update!()
    end)
  end

  defp totp_uri(user) do
    issuer_name = Plausible.product_name()
    NimbleTOTP.otpauth_uri("#{issuer_name}:#{user.email}", user.totp_secret, issuer: issuer_name)
  end

  defp readable_secret(user) do
    Base.encode32(user.totp_secret, padding: false)
  end

  defp recovery_codes_query(user) do
    from(rc in TOTP.RecoveryCode, where: rc.user_id == ^user.id)
  end

  defp do_validate_code(user, code, opts) do
    # Necessary because we must be sure the timestamp is current.
    # User struct stored in liveview context on mount might be
    # pretty out of date, for instance.
    last_used =
      if Keyword.get(opts, :allow_reuse?) do
        nil
      else
        fetch_last_used(user)
      end

    time = System.os_time(:second)

    if NimbleTOTP.valid?(user.totp_secret, code, since: last_used, time: time) or
         NimbleTOTP.valid?(user.totp_secret, code, since: last_used, time: time - 30) do
      {:ok, bump_last_used!(user)}
    else
      {:error, :invalid_code}
    end
  end

  defp fetch_last_used(user) do
    datetime =
      from(u in Plausible.Auth.User, where: u.id == ^user.id, select: u.totp_last_used_at)
      |> Repo.one()

    if datetime do
      Timex.to_unix(datetime)
    end
  end

  defp bump_last_used!(user) do
    now = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)

    user
    |> change(totp_last_used_at: now)
    |> Repo.update!()
  end

  defp generate_token() do
    20
    |> :crypto.strong_rand_bytes()
    |> Base.encode64(padding: false)
  end
end
