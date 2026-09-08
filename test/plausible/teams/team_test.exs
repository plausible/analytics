defmodule Plausible.Teams.TeamTest do
  use Plausible.DataCase, async: true

  alias Plausible.Teams.Team

  @too_long_error {"should be at most %{count} character(s)",
                   [count: 50, validation: :length, kind: :max, type: :string]}
  @too_many_bytes_error {"should be at most %{count} byte(s)",
                         [count: 255, validation: :length, kind: :max, type: :binary]}
  @url_error {"cannot contain a URL", []}

  describe "name_changeset/2" do
    test "accepts a name at exactly the limit" do
      assert Team.name_changeset(%Team{}, %{name: String.duplicate("a", 50)}).errors == []
    end

    test "rejects a name one character over the limit" do
      assert Team.name_changeset(%Team{}, %{name: String.duplicate("a", 51)}).errors == [
               name: @too_long_error
             ]
    end

    test "rejects a name that fits the limit but overflows the column" do
      # 50 graphemes of family emoji is 350 code points in a varchar(255)
      name = String.duplicate("👨‍👩‍👧‍👦", 50)

      assert String.length(name) == 50
      assert Team.name_changeset(%Team{}, %{name: name}).errors == [name: @too_many_bytes_error]
    end

    test "rejects names carrying a URL scheme" do
      for name <- [
            "https://spam.example.com",
            "http://spam.example.com/buy?x=1",
            "Cheap meds at https://spam.example.com",
            "ftp://spam.example.com",
            "HTTPS://SPAM.EXAMPLE.COM"
          ] do
        assert Team.name_changeset(%Team{}, %{name: name}).errors == [name: @url_error],
               "expected #{inspect(name)} to be rejected"
      end
    end

    test "accepts names without a scheme, bare hostnames included" do
      for name <- [
            "My Team",
            "spam.example.com",
            "www.spam.example.com",
            "hello@spam.example.com",
            "Team example.co.uk",
            "Vue.js Team",
            "St. Louis Marketing",
            "Smith & Co.",
            "A-Team!"
          ] do
        assert Team.name_changeset(%Team{}, %{name: name}).errors == [],
               "expected #{inspect(name)} to be accepted"
      end
    end
  end

  describe "changeset/3 and crm_changeset/2" do
    test "reject a name over the limit" do
      name = String.duplicate("a", 51)

      assert Team.changeset(%Team{}, %{name: name}).errors == [name: @too_long_error]
      assert Team.crm_changeset(%Team{}, %{name: name}).errors == [name: @too_long_error]
    end

    test "reject a name carrying a URL scheme" do
      name = "https://spam.example.com"

      assert Team.changeset(%Team{}, %{name: name}).errors == [name: @url_error]
      assert Team.crm_changeset(%Team{}, %{name: name}).errors == [name: @url_error]
    end
  end

  describe "names already stored in violation of the rules" do
    test "stay valid as long as the name is not changed" do
      for stored <- [String.duplicate("a", 80), "https://spam.example.com"] do
        team = new_user(team: [name: stored]) |> team_of()

        assert team.name == stored
        assert Team.name_changeset(team).errors == []
        assert Team.name_changeset(team, %{name: stored}).errors == []
      end
    end

    test "can be renamed to a name within the limit" do
      team = new_user(team: [name: String.duplicate("a", 80)]) |> team_of()

      assert {:ok, team} = Repo.update(Team.name_changeset(team, %{name: "Shorter"}))
      assert team.name == "Shorter"
    end

    test "cannot be renamed to another name over the limit" do
      team = new_user(team: [name: String.duplicate("a", 80)]) |> team_of()

      assert Team.name_changeset(team, %{name: String.duplicate("b", 51)}).errors == [
               name: @too_long_error
             ]

      assert Team.name_changeset(team, %{name: "https://spam.example.com"}).errors == [
               name: @url_error
             ]
    end
  end

  describe "suggested_name/1" do
    test "appends the suffix to a short name" do
      assert Team.suggested_name("Jane") == "Jane's team"
    end

    test "shortens a long name so that the result fits the limit" do
      assert Team.suggested_name(String.duplicate("a", 55)) ==
               String.duplicate("a", 43) <> "'s team"
    end

    test "trims the whitespace that shortening leaves behind" do
      assert Team.suggested_name(String.duplicate("a", 42) <> " Smith") ==
               String.duplicate("a", 42) <> "'s team"
    end

    test "falls back to a generic name when shortening still overflows the column" do
      assert Team.suggested_name(String.duplicate("👨‍👩‍👧‍👦", 36)) == "My team"
    end

    test "falls back to a generic name when the user has no name" do
      assert Team.suggested_name(nil) == "My team"
    end

    test "falls back to a generic name when the user name carries a URL scheme" do
      assert Team.suggested_name("Cheap meds https://spam.example.com") == "My team"
    end

    test "falls back to a generic name when a URL scheme survives shortening" do
      assert Team.suggested_name("https://spam.example.com " <> String.duplicate("a", 55)) ==
               "My team"
    end

    test "keeps the shortened name when shortening cuts the URL scheme off" do
      assert Team.suggested_name(String.duplicate("a", 50) <> " https://spam.example.com") ==
               String.duplicate("a", 43) <> "'s team"
    end

    test "always returns a name the changeset accepts" do
      for user_name <- [
            "Jane",
            nil,
            String.duplicate("a", 55),
            String.duplicate("👨‍👩‍👧‍👦", 36),
            "Cheap meds https://spam.example.com"
          ] do
        suggested = Team.suggested_name(user_name)

        assert Team.name_changeset(%Team{}, %{name: suggested}).errors == [],
               "expected #{inspect(suggested)} to be accepted"
      end
    end
  end
end
