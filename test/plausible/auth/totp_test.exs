defmodule Plausible.Auth.TOTPTest do
  use Plausible.DataCase, async: true

  alias Plausible.Auth.TOTP
  alias Plausible.Auth.TOTP.RecoveryCode

  alias Plausible.Repo

  describe "enabled?/1" do
    test "Returns user's TOTP state" do
      assert TOTP.enabled?(insert(:user, totp_enabled: true, totp_secret: "secret"))
      refute TOTP.enabled?(insert(:user, totp_enabled: false, totp_secret: nil))
      # these shouldn't happen under normal circumstances but we do check
      # totp_secret presence just to be safe and avoid undefined behavior
      refute TOTP.enabled?(insert(:user, totp_enabled: false, totp_secret: "secret"))
      refute TOTP.enabled?(insert(:user, totp_enabled: true, totp_secret: nil))
    end
  end

  describe "initiate/1" do
    test "initiates TOTP setup for user" do
      user = insert(:user)

      assert {:ok, updated_user, params} = TOTP.initiate(user)

      assert updated_user.id == user.id
      refute updated_user.totp_enabled
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
      assert byte_size(updated_user.totp_secret) > 0
      assert updated_user.totp_secret != user.totp_secret
    end

    test "does not initiate setup for user with TOTP already enabled" do
      user = insert(:user)
      {:ok, user, _} = TOTP.initiate(user)
      code = NimbleTOTP.verification_code(user.totp_secret)
      {:ok, user} = TOTP.enable(user, code)

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

      assert {:ok, user} = TOTP.enable(user, code)

      assert user.totp_enabled
      assert byte_size(user.totp_secret) > 0
    end

    test "succeeds for user who has TOTP enabled already" do
      user = insert(:user)
      {:ok, user, _} = TOTP.initiate(user)
      code = NimbleTOTP.verification_code(user.totp_secret, time: System.os_time(:second) - 30)
      {:ok, user} = TOTP.enable(user, code)

      assert {:ok, updated_user} = TOTP.enable(user, code, allow_reuse?: true)

      assert updated_user.id == user.id
      assert updated_user.totp_enabled
      assert updated_user.totp_secret == user.totp_secret
    end

    test "fails when TOTP setup is not initiated" do
      user = insert(:user)

      assert {:error, :not_initiated} = TOTP.enable(user, "123456")
    end

    test "fails when invalid code is provided" do
      user = insert(:user)
      {:ok, user, _} = TOTP.initiate(user)

      assert {:error, :invalid_code} = TOTP.enable(user, "1234")
    end
  end

  describe "disable/2" do
    test "disables TOTP for user who has it enabled" do
      user = insert(:user, password: "VeryStrongVerySecret")
      {:ok, user, _} = TOTP.initiate(user)
      code = NimbleTOTP.verification_code(user.totp_secret)
      {:ok, user} = TOTP.enable(user, code)

      assert {:ok, updated_user} = TOTP.disable(user, "VeryStrongVerySecret")

      assert updated_user.id == user.id
      refute updated_user.totp_enabled
      assert is_nil(updated_user.totp_secret)

      assert Repo.all(RecoveryCode) == []
    end

    test "succeeds for user who does not have TOTP enabled" do
      user = insert(:user, password: "VeryStrongVerySecret")

      assert {:ok, updated_user} = TOTP.disable(user, "VeryStrongVerySecret")

      assert updated_user.id == user.id
      refute updated_user.totp_enabled
      assert is_nil(updated_user.totp_secret)
    end

    test "fails when invalid password is provided" do
      user = insert(:user, password: "VeryStrongVerySecret")
      {:ok, user, _} = TOTP.initiate(user)
      code = NimbleTOTP.verification_code(user.totp_secret)
      {:ok, user} = TOTP.enable(user, code)

      assert {:error, :invalid_password} = TOTP.disable(user, "invalid")
    end
  end

  describe "generate_recovery_codes/1" do
    test "generates recovery codes for user with enabled TOTP" do
      user = insert(:user)
      {:ok, user, _} = TOTP.initiate(user)
      code = NimbleTOTP.verification_code(user.totp_secret)
      {:ok, user} = TOTP.enable(user, code)

      assert {:ok, codes} = TOTP.generate_recovery_codes(user)

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

    test "regenerates recovery codes when generated already" do
      user = insert(:user)
      {:ok, user, _} = TOTP.initiate(user)
      code = NimbleTOTP.verification_code(user.totp_secret)
      {:ok, user} = TOTP.enable(user, code)

      assert {:ok, [code | codes]} = TOTP.generate_recovery_codes(user)
      assert :ok = TOTP.use_recovery_code(user, code)

      assert {:ok, new_codes} = TOTP.generate_recovery_codes(user)

      assert Enum.uniq(codes ++ new_codes) == codes ++ new_codes

      assert length(new_codes) == 10

      Enum.each(new_codes, fn code ->
        assert byte_size(code) > 0
        assert :ok = TOTP.use_recovery_code(user, code)
      end)
    end

    test "fails when user has TOTP disabled" do
      user = insert(:user)

      assert {:error, :not_enabled} = TOTP.generate_recovery_codes(user)
    end
  end

  describe "generate_recovery_codes_protected/1" do
    test "generates recovery codes for user with enabled TOTP" do
      user = insert(:user, password: "VeryStrongVerySecret")
      {:ok, user, _} = TOTP.initiate(user)
      code = NimbleTOTP.verification_code(user.totp_secret)
      {:ok, user} = TOTP.enable(user, code)

      assert {:ok, codes} = TOTP.generate_recovery_codes_protected(user, "VeryStrongVerySecret")

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
               TOTP.generate_recovery_codes_protected(user, "VeryStrongVerySecret")
    end

    test "fails when invalid password provided" do
      user = insert(:user, password: "VeryStrongVerySecret")
      {:ok, user, _} = TOTP.initiate(user)
      code = NimbleTOTP.verification_code(user.totp_secret)
      {:ok, user} = TOTP.enable(user, code)

      assert {:error, :invalid_password} = TOTP.generate_recovery_codes_protected(user, "invalid")
    end
  end

  describe "validate_code/2" do
    test "succeeds when valid code provided and respects grace period" do
      user = insert(:user)
      {:ok, user, _} = TOTP.initiate(user)
      code = NimbleTOTP.verification_code(user.totp_secret, time: System.os_time(:second) - 30)
      {:ok, user} = TOTP.enable(user, code)
      new_code = NimbleTOTP.verification_code(user.totp_secret)

      # making sure that generated OTP codes are different
      assert code != new_code

      assert {:ok, user} = TOTP.validate_code(user, code, allow_reuse?: true)

      assert_in_delta Timex.to_unix(user.totp_last_used_at), System.os_time(:second), 2
    end

    test "fails when trying to reuse the same code twice" do
      user = insert(:user)
      {:ok, user, _} = TOTP.initiate(user)
      code = NimbleTOTP.verification_code(user.totp_secret, time: System.os_time(:second) - 30)
      {:ok, user} = TOTP.enable(user, code)

      assert {:error, :invalid_code} = TOTP.validate_code(user, code)
    end

    test "fails when invalid code provided" do
      user = insert(:user)
      {:ok, user, _} = TOTP.initiate(user)
      code = NimbleTOTP.verification_code(user.totp_secret)
      {:ok, user} = TOTP.enable(user, code)

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
      user = insert(:user)
      {:ok, user, _} = TOTP.initiate(user)
      code = NimbleTOTP.verification_code(user.totp_secret)
      {:ok, user} = TOTP.enable(user, code)
      {:ok, [code | codes]} = TOTP.generate_recovery_codes(user)

      assert :ok = TOTP.use_recovery_code(user, code)
      assert {:error, :invalid_code} = TOTP.use_recovery_code(user, code)

      assert length(Repo.all(RecoveryCode)) == length(codes)
    end

    test "fails when provided code is invalid" do
      user = insert(:user)
      {:ok, user, _} = TOTP.initiate(user)
      code = NimbleTOTP.verification_code(user.totp_secret)
      {:ok, user} = TOTP.enable(user, code)
      {:ok, _} = TOTP.generate_recovery_codes(user)

      assert {:error, :invalid_code} = TOTP.use_recovery_code(user, "INVALID")
    end

    test "fails when there are no recovery codes to check against" do
      user = insert(:user)
      {:ok, user, _} = TOTP.initiate(user)
      code = NimbleTOTP.verification_code(user.totp_secret)
      {:ok, user} = TOTP.enable(user, code)

      assert {:error, :invalid_code} = TOTP.use_recovery_code(user, "INVALID")
    end

    test "fails when user has TOTP disabled even though provided code is valid" do
      user = insert(:user, password: "VeryStrongVerySecret")
      {:ok, user, _} = TOTP.initiate(user)
      code = NimbleTOTP.verification_code(user.totp_secret)
      {:ok, user} = TOTP.enable(user, code)
      {:ok, [code | _]} = TOTP.generate_recovery_codes(user)
      {:ok, user} = TOTP.disable(user, "VeryStrongVerySecret")

      assert {:error, :not_enabled} = TOTP.user_recovery_code(user, code)
    end
  end
end
