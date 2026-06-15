defmodule Plausible.Auth.TOTP.FallbackVaultTest do
  use Plausible.DataCase, async: true

  alias Plausible.Auth.TOTP.FallbackVault

  describe "encrypting secrets" do
    test "encryption works" do
      plain_secret = "super secret"
      encrypted_secret = FallbackVault.encrypt!(plain_secret)
      decrypted_secret = FallbackVault.decrypt!(encrypted_secret)

      assert encrypted_secret != plain_secret
      assert decrypted_secret == plain_secret
    end

    test "TOTP secret is stored encrypted and decrypted on read" do
      secret = NimbleTOTP.secret()

      user = insert(:user, totp_secret_fallback: secret)
      user = Repo.reload!(user)

      assert user.totp_secret_fallback == secret

      {:ok, %{rows: [[totp_secret_in_db]]}} =
        Repo.query("SELECT totp_secret_fallback from users where id = $1", [user.id])

      assert totp_secret_in_db != secret
    end
  end
end
