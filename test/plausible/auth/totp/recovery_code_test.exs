defmodule Plausible.Auth.TOTP.RecoveryCodeTest do
  use Plausible.DataCase, async: true

  alias Plausible.Auth.TOTP.RecoveryCode

  describe "generate_codes/1" do
    test "generates random codes conforming agreed upon format" do
      codes = RecoveryCode.generate_codes(3)

      Enum.each(codes, fn code ->
        assert Regex.match?(~r/[A-Z0-9]{10}/, code)
      end)

      assert codes == Enum.uniq(codes)
    end
  end

  describe "match?/1" do
    test "verifies that provided code matches against a digest of stored recovery code" do
      [plain_code] = RecoveryCode.generate_codes(1)

      recovery_code =
        build(:user)
        |> RecoveryCode.changeset(plain_code)
        |> Ecto.Changeset.apply_changes()

      assert RecoveryCode.match?(recovery_code, plain_code)
      refute RecoveryCode.match?(recovery_code, "INVALID")
    end
  end

  describe "changeset/2" do
    test "builds a valid changeset when provided valid code format" do
      [plain_code] = RecoveryCode.generate_codes(1)

      changeset = RecoveryCode.changeset(build(:user), plain_code)

      assert changeset.valid?
      assert changeset.changes.user
      assert changeset.changes.code_digest

      assert RecoveryCode.match?(Ecto.Changeset.apply_changes(changeset), plain_code)
    end

    test "crashes when code in invalid format is passed" do
      user = build(:user)

      assert_raise FunctionClauseError, fn ->
        RecoveryCode.changeset(user, "INVALID")
      end

      assert_raise FunctionClauseError, fn ->
        RecoveryCode.changeset(user, 123)
      end
    end
  end

  describe "changeset_to_map/2" do
    test "converts changeset to a map suitable for Repo.insert_all/3" do
      user = %{id: user_id} = new_user()
      [plain_code] = RecoveryCode.generate_codes(1)

      changeset =
        %{changes: %{code_digest: code_digest}} = RecoveryCode.changeset(user, plain_code)

      now = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)

      assert %{
               user_id: ^user_id,
               code_digest: ^code_digest,
               inserted_at: ^now
             } = RecoveryCode.changeset_to_map(changeset, now)
    end
  end

  describe "disambiguate/1" do
    test "disambiguates strings with hard to discern letters" do
      assert RecoveryCode.disambiguate("ABDIZL12") == "ABD7ZL12"
      assert RecoveryCode.disambiguate("ABDIZLO12") == "ABD7ZL812"
      assert RecoveryCode.disambiguate("AOBDIZLO12I") == "A8BD7ZL8127"
    end

    test "leaves strings that have no sunch letters intact" do
      assert RecoveryCode.disambiguate("N0D0UBT") == "N0D0UBT"
    end
  end
end
