defmodule Plausible.Auth.UserTest do
  use Plausible.DataCase, async: true

  alias Plausible.Auth.User

  describe "settings_changeset/2" do
    test "fails for empty input and user" do
      changeset = User.settings_changeset(%User{}, %{})

      refute changeset.valid?
    end

    test "succeeds for non-empty user even if input is empty" do
      changeset =
        User.settings_changeset(
          %User{name: "Mary Jane", email: "mary@plausible.test", theme: "system"},
          %{}
        )

      assert changeset.valid?
    end

    test "succeeds for valid user details input" do
      changeset =
        User.settings_changeset(
          %User{name: "Mary Jane", email: "mary@plausible.test", theme: "system"},
          %{name: "Tony Mangle", email: "tony@plausible.test"}
        )

      assert changeset.valid?
      assert changeset.changes == %{name: "Tony Mangle", email: "tony@plausible.test"}
    end

    test "succeeds for valid theme input" do
      changeset =
        User.settings_changeset(
          %User{name: "Mary Jane", email: "mary@plausible.test", theme: "system"},
          %{theme: "dark"}
        )

      assert changeset.valid?
      assert changeset.changes == %{theme: :dark}
    end

    test "fails on invalid user details input" do
      changeset =
        User.settings_changeset(
          %User{name: "Mary Jane", email: "mary@plausible.test", theme: "system"},
          %{name: ""}
        )

      refute changeset.valid?
      assert changeset.errors[:name]
    end

    test "fails on invalid theme input" do
      changeset =
        User.settings_changeset(
          %User{name: "Mary Jane", email: "mary@plausible.test", theme: "system"},
          %{theme: "invalid"}
        )

      refute changeset.valid?
      assert changeset.errors[:theme]
    end
  end

  describe "password_strength/1" do
    test "scores password with all arguments in changes" do
      assert %{score: score, warning: warning, suggestions: suggestions} =
               %User{}
               |> change(
                 name: "Jane Doe",
                 email: "user@example.com",
                 password: "asd"
               )
               |> User.password_strength()

      assert score < 3
      assert warning != ""
      assert length(suggestions) > 0
    end

    test "checks for existing phrases using name and email from changes" do
      strength =
        %User{}
        |> change(
          name: "Clayman Sillywaggle",
          email: "clay@example.com",
          password: "claymansillywaggle"
        )
        |> User.password_strength()

      assert strength.score == 1
    end

    test "checks for existing phrases using name and email from source" do
      strength =
        %User{
          name: "Clayman Sillywaggle",
          email: "clay@example.com"
        }
        |> change(password: "claymansillywaggle")
        |> User.password_strength()

      assert strength.score == 1
    end

    test "treats passwords past 32 bytes as very strong" do
      strength =
        %User{
          name: "Clayman Sillywaggle",
          email: "clay@example.com"
        }
        |> change(password: String.duplicate("a", 33))
        |> User.password_strength()

      assert strength.score == 4
    end
  end

  describe "password strength validation" do
    test "succeeds for complex enough password" do
      changeset =
        User.new(%{
          name: "Jane Doe",
          email: "jane@example.com",
          password: "very-secret-and-very-long-123",
          password_confirmation: "very-secret-and-very-long-123"
        })

      assert changeset.valid?
    end

    test "fails for password not complex enough" do
      changeset =
        User.new(%{
          name: "Jane Doe",
          email: "jane@example.com",
          password: "asdasdasdasd",
          password_confirmation: "asdasdasdasd"
        })

      refute changeset.valid?
      assert {"is too weak", [validation: :strength]} = changeset.errors[:password]
    end
  end
end
