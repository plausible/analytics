defmodule Plausible.Auth.TOTPTest do
  use Plausible.DataCase, async: true
  use Bamboo.Test

  alias Plausible.Auth.TOTP
  alias Plausible.Auth.TOTP.RecoveryCode

  alias Plausible.Repo

  describe "enabled?/1" do
    test "Returns user's TOTP state" do
      refute TOTP.enabled?(insert(:user, totp_enabled: false, totp_secret: nil))
      refute TOTP.enabled?(insert(:user, totp_enabled: false, totp_secret: "secret"))
      assert TOTP.enabled?(insert(:user, totp_enabled: true, totp_secret: "secret"))
      # this shouldn't happen under normal circumstances but we do check
      # totp_secret presence just to be safe and avoid undefined behavior
      refute TOTP.enabled?(insert(:user, totp_enabled: true, totp_secret: nil))
    end
  end

  describe "initiated?/1" do
    test "Returns true only when user's TOTP setup is initiated but not finalized" do
      refute TOTP.initiated?(insert(:user, totp_enabled: false, totp_secret: nil))
      refute TOTP.initiated?(insert(:user, totp_enabled: true, totp_secret: "secret"))
      assert TOTP.initiated?(insert(:user, totp_enabled: false, totp_secret: "secret"))
      # this shouldn't happen under normal circumstances but we do check
      # totp_secret presence just to be safe and avoid undefined behavior
      refute TOTP.enabled?(insert(:user, totp_enabled: true, totp_secret: nil))
    end
  end

  describe "initiate/1" do
    test "initiates TOTP setup for user" do
      user = insert(:user)

      assert {:ok, updated_user, params} = TOTP.initiate(user)

      assert updated_user.id == user.id
      refute updated_user.totp_enabled
      assert is_nil(updated_user.totp_token)
      assert byte_size(updated_user.totp_secret) > 0

      assert Regex.match?(~r/[0-9A-Z]+/, params.secret)
      assert String.starts_with?(params.totp_uri, "otpauth://totp")
    end

    test "reinitiates setup for user with unfinished TOTP setup" do
      user = insert(:user)
      {:ok, user, params} = TOTP.initiate(user)

      assert {:ok, updated_user, new_params} = TOTP.initiate(user)

      assert new_params.totp_uri != params.totp_uri
      assert new_params.secret != params.secret

      refute updated_user.totp_enabled
      assert is_nil(updated_user.totp_token)
      assert byte_size(updated_user.totp_secret) > 0
      assert updated_user.totp_secret != user.totp_secret
    end

    test "does not initiate setup for user with TOTP already enabled" do
      user = insert(:user)
      {:ok, user, _} = TOTP.initiate(user)
      code = NimbleTOTP.verification_code(user.totp_secret)
      {:ok, user, _} = TOTP.enable(user, code)

      assert TOTP.initiate(user) == {:error, :already_setup}
    end

    test "does not initiate setup for user with unverified email" do
      user = insert(:user, email_verified: false)

      assert TOTP.initiate(user) == {:error, :not_verified}
    end
  end

  describe "enable/2" do
    test "finishes setting up TOTP for user" do
      user = insert(:user)
      {:ok, user, _} = TOTP.initiate(user)
      code = NimbleTOTP.verification_code(user.totp_secret)

      assert {:ok, user, %{recovery_codes: recovery_codes}} = TOTP.enable(user, code)

      assert_email_delivered_with(
        to: [{user.name, user.email}],
        subject: "Plausible Two-Factor Authentication enabled"
      )

      assert user.totp_enabled
      assert byte_size(user.totp_token) > 0
      assert byte_size(user.totp_secret) > 0

      persisted_recovery_codes = Repo.all(RecoveryCode)

      assert length(recovery_codes) == 10
      assert length(persisted_recovery_codes) == 10

      Enum.each(persisted_recovery_codes, fn recovery_code ->
        assert recovery_code.user_id == user.id
        assert byte_size(recovery_code.code_digest) > 0
      end)

      Enum.each(recovery_codes, fn code_string ->
        assert byte_size(code_string) > 0
        assert :ok = TOTP.use_recovery_code(user, code_string)
      end)
    end

    test "succeeds for user who has TOTP enabled already" do
      user = insert(:user)
      {:ok, user, _} = TOTP.initiate(user)
      code = NimbleTOTP.verification_code(user.totp_secret, time: System.os_time(:second) - 30)
      {:ok, user, %{recovery_codes: [recovery_code | recovery_codes]}} = TOTP.enable(user, code)
      :ok = TOTP.use_recovery_code(user, recovery_code)

      new_code = NimbleTOTP.verification_code(user.totp_secret)

      assert {:ok, updated_user, %{recovery_codes: new_recovery_codes}} =
               TOTP.enable(user, new_code, allow_reuse?: true)

      assert updated_user.id == user.id
      assert updated_user.totp_enabled
      assert byte_size(updated_user.totp_token) > 0
      assert updated_user.totp_token != user.totp_token
      assert updated_user.totp_secret == user.totp_secret

      assert Enum.uniq(recovery_codes ++ new_recovery_codes) ==
               recovery_codes ++ new_recovery_codes

      assert length(new_recovery_codes) == 10

      Enum.each(new_recovery_codes, fn code_string ->
        assert byte_size(code_string) > 0
        assert :ok = TOTP.use_recovery_code(user, code_string)
      end)
    end

    test "fails when TOTP setup is not initiated" do
      user = insert(:user)

      assert {:error, :not_initiated} = TOTP.enable(user, "123456")
      assert_no_emails_delivered()
    end

    test "fails when invalid code is provided" do
      user = insert(:user)
      {:ok, user, _} = TOTP.initiate(user)

      assert {:error, :invalid_code} = TOTP.enable(user, "1234")
      assert_no_emails_delivered()
    end
  end

  describe "disable/2" do
    test "disables TOTP for user who has it enabled" do
      user = insert(:user, password: "VeryStrongVerySecret")
      {:ok, user, _} = TOTP.initiate(user)
      code = NimbleTOTP.verification_code(user.totp_secret)
      {:ok, user, _} = TOTP.enable(user, code)

      assert_email_delivered_with(
        to: [{user.name, user.email}],
        subject: "Plausible Two-Factor Authentication enabled"
      )

      assert {:ok, updated_user} = TOTP.disable(user, "VeryStrongVerySecret")

      assert_email_delivered_with(
        to: [{user.name, user.email}],
        subject: "Plausible Two-Factor Authentication disabled"
      )

      assert updated_user.id == user.id
      refute updated_user.totp_enabled
      assert is_nil(updated_user.totp_token)
      assert is_nil(updated_user.totp_secret)

      assert Repo.all(RecoveryCode) == []
    end

    test "succeeds for user who does not have TOTP enabled" do
      user = insert(:user, password: "VeryStrongVerySecret")

      assert {:ok, updated_user} = TOTP.disable(user, "VeryStrongVerySecret")

      assert updated_user.id == user.id
      refute updated_user.totp_enabled
      assert is_nil(updated_user.totp_token)
      assert is_nil(updated_user.totp_secret)
    end

    test "fails when invalid password is provided" do
      user = insert(:user, password: "VeryStrongVerySecret")
      {:ok, user, _} = TOTP.initiate(user)
      code = NimbleTOTP.verification_code(user.totp_secret)
      {:ok, user, _} = TOTP.enable(user, code)

      assert_email_delivered_with(
        to: [{user.name, user.email}],
        subject: "Plausible Two-Factor Authentication enabled"
      )

      assert {:error, :invalid_password} = TOTP.disable(user, "invalid")

      assert_no_emails_delivered()
    end
  end

  describe "force_disable/1" do
    test "disables TOTP for user who has it enabled" do
      user = insert(:user, password: "VeryStrongVerySecret")
      {:ok, user, _} = TOTP.initiate(user)
      code = NimbleTOTP.verification_code(user.totp_secret)
      {:ok, user, _} = TOTP.enable(user, code)

      assert_email_delivered_with(
        to: [{user.name, user.email}],
        subject: "Plausible Two-Factor Authentication enabled"
      )

      assert {:ok, updated_user} = TOTP.force_disable(user)

      assert updated_user.id == user.id
      refute updated_user.totp_enabled
      assert is_nil(updated_user.totp_token)
      assert is_nil(updated_user.totp_secret)

      assert Repo.all(RecoveryCode) == []
    end

    test "succeeds for user who does not have TOTP enabled" do
      user = insert(:user, password: "VeryStrongVerySecret")

      assert {:ok, updated_user} = TOTP.force_disable(user)

      assert updated_user.id == user.id
      refute updated_user.totp_enabled
      assert is_nil(updated_user.totp_token)
      assert is_nil(updated_user.totp_secret)
    end
  end

  describe "reset_token/1" do
    test "generates new token when TOTP enabled" do
      user = insert(:user, password: "VeryStrongVerySecret")
      {:ok, user, _} = TOTP.initiate(user)
      code = NimbleTOTP.verification_code(user.totp_secret)
      {:ok, user, _} = TOTP.enable(user, code)

      assert %{totp_token: new_token} = TOTP.reset_token(user)

      assert byte_size(new_token) > 0
      assert new_token != user.totp_token
    end

    test "sets to nil when TOTP disabled" do
      user = insert(:user)

      assert %{totp_token: nil} = TOTP.reset_token(user)

      user2 = insert(:user, password: "VeryStrongVerySecret")
      {:ok, user2, _} = TOTP.initiate(user2)
      code = NimbleTOTP.verification_code(user2.totp_secret)
      {:ok, user2, _} = TOTP.enable(user2, code)
      {:ok, user2} = TOTP.disable(user2, "VeryStrongVerySecret")

      assert %{totp_token: nil} = TOTP.reset_token(user2)

      user3 = insert(:user)
      {:ok, user3, _} = TOTP.initiate(user3)

      assert %{totp_token: nil} = TOTP.reset_token(user3)
    end
  end

  describe "generate_recovery_codes/1" do
    test "generates recovery codes for user with enabled TOTP" do
      user = insert(:user, password: "VeryStrongVerySecret")
      {:ok, user, _} = TOTP.initiate(user)
      code = NimbleTOTP.verification_code(user.totp_secret)
      {:ok, user, _} = TOTP.enable(user, code)

      assert {:ok, codes} = TOTP.generate_recovery_codes(user, "VeryStrongVerySecret")

      persisted_codes = Repo.all(RecoveryCode)

      assert length(codes) == 10
      assert length(persisted_codes) == 10

      Enum.each(persisted_codes, fn recovery_code ->
        assert recovery_code.user_id == user.id
        assert byte_size(recovery_code.code_digest) > 0
      end)

      Enum.each(codes, fn code ->
        assert byte_size(code) > 0
        assert :ok = TOTP.use_recovery_code(user, code)
      end)
    end

    test "fails when user has TOTP disabled" do
      user = insert(:user, password: "VeryStrongVerySecret")

      assert {:error, :not_enabled} =
               TOTP.generate_recovery_codes(user, "VeryStrongVerySecret")
    end

    test "fails when invalid password provided" do
      user = insert(:user, password: "VeryStrongVerySecret")
      {:ok, user, _} = TOTP.initiate(user)
      code = NimbleTOTP.verification_code(user.totp_secret)
      {:ok, user, _} = TOTP.enable(user, code)

      assert {:error, :invalid_password} = TOTP.generate_recovery_codes(user, "invalid")
    end
  end

  describe "validate_code/2" do
    test "succeeds when valid code provided and respects grace period" do
      user = insert(:user)
      {:ok, user, _} = TOTP.initiate(user)
      code = NimbleTOTP.verification_code(user.totp_secret, time: System.os_time(:second) - 30)
      {:ok, user, _} = TOTP.enable(user, code)
      new_code = NimbleTOTP.verification_code(user.totp_secret)

      # making sure that generated OTP codes are different
      assert code != new_code

      assert {:ok, user} = TOTP.validate_code(user, new_code, allow_reuse?: true)

      assert_in_delta Timex.to_unix(user.totp_last_used_at), System.os_time(:second), 2
    end

    test "fails when trying to reuse the same code twice" do
      user = insert(:user)
      {:ok, user, _} = TOTP.initiate(user)
      code = NimbleTOTP.verification_code(user.totp_secret, time: System.os_time(:second) - 30)
      {:ok, user, _} = TOTP.enable(user, code)

      assert {:error, :invalid_code} = TOTP.validate_code(user, code)
    end

    test "fails when invalid code provided" do
      user = insert(:user)
      {:ok, user, _} = TOTP.initiate(user)
      code = NimbleTOTP.verification_code(user.totp_secret)
      {:ok, user, _} = TOTP.enable(user, code)

      assert {:error, :invalid_code} = TOTP.validate_code(user, "1234")
    end

    test "fails when user has TOTP initiated but not enabled" do
      user = insert(:user)
      {:ok, user, _} = TOTP.initiate(user)
      code = NimbleTOTP.verification_code(user.totp_secret)

      assert {:error, :not_enabled} = TOTP.validate_code(user, code)
    end
  end

  describe "use_recovery_code/2" do
    test "succeeds when valid recovery code provided but fails when trying to reuse it" do
      user = insert(:user, password: "VeryStrongVerySecret")
      {:ok, user, _} = TOTP.initiate(user)
      code = NimbleTOTP.verification_code(user.totp_secret)
      {:ok, user, _} = TOTP.enable(user, code)
      {:ok, [code | codes]} = TOTP.generate_recovery_codes(user, "VeryStrongVerySecret")

      assert :ok = TOTP.use_recovery_code(user, code)
      assert {:error, :invalid_code} = TOTP.use_recovery_code(user, code)

      assert length(Repo.all(RecoveryCode)) == length(codes)
    end

    test "fails when provided code is invalid" do
      user = insert(:user, password: "VeryStrongVerySecret")
      {:ok, user, _} = TOTP.initiate(user)
      code = NimbleTOTP.verification_code(user.totp_secret)
      {:ok, user, _} = TOTP.enable(user, code)
      {:ok, _} = TOTP.generate_recovery_codes(user, "VeryStrongVerySecret")

      assert {:error, :invalid_code} = TOTP.use_recovery_code(user, "INVALID")
    end

    test "fails when there are no recovery codes to check against" do
      user = insert(:user)
      {:ok, user, _} = TOTP.initiate(user)
      code = NimbleTOTP.verification_code(user.totp_secret)
      {:ok, user, _} = TOTP.enable(user, code)

      assert {:error, :invalid_code} = TOTP.use_recovery_code(user, "INVALID")
    end

    test "fails when user has TOTP disabled even though provided code is valid" do
      user = insert(:user, password: "VeryStrongVerySecret")
      {:ok, user, _} = TOTP.initiate(user)
      code = NimbleTOTP.verification_code(user.totp_secret)
      {:ok, user, _} = TOTP.enable(user, code)
      {:ok, [code | _]} = TOTP.generate_recovery_codes(user, "VeryStrongVerySecret")
      {:ok, user} = TOTP.disable(user, "VeryStrongVerySecret")

      assert {:error, :not_enabled} = TOTP.use_recovery_code(user, code)
    end
  end
end
