defmodule Plausible.Workers.CleanEmailVerificationCodesTest do
  use Plausible.DataCase
  alias Plausible.Workers.CleanEmailVerificationCodes

  defp issue_code(user, issued_at) do
    code =
      Repo.one(
        from(c in "email_verification_codes", where: is_nil(c.user_id), select: c.code, limit: 1)
      )

    Repo.update_all(from(c in "email_verification_codes", where: c.code == ^code),
      set: [user_id: user.id, issued_at: issued_at]
    )
  end

  test "cleans codes that are more than 4 hours old" do
    user = insert(:user)
    issue_code(user, Timex.now() |> Timex.shift(hours: -5))
    issue_code(user, Timex.now() |> Timex.shift(days: -5))

    CleanEmailVerificationCodes.perform(nil)

    refute Repo.exists?(from c in "email_verification_codes", where: c.user_id == ^user.id)
  end

  test "does not clean code from 2 hours ago" do
    user = insert(:user)
    issue_code(user, Timex.now() |> Timex.shift(hours: -2))

    CleanEmailVerificationCodes.perform(nil)

    assert Repo.exists?(from c in "email_verification_codes", where: c.user_id == ^user.id)
  end
end
