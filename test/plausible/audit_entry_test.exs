defmodule Plausible.AuditEntryTest do
  use Plausible.Teams.Test
  use Plausible.DataCase, async: true

  alias Plausible.Audit
  alias Plausible.Repo

  describe "persistence" do
    test "persists most basic audit entry" do
      Audit.new("test_entry", entity: Plausible.Auth.User, entity_id: "1") |> Audit.persist()

      assert [
               %Plausible.Audit.Entry{
                 id: _,
                 name: "test_entry",
                 entity: "Plausible.Auth.User",
                 entity_id: "1",
                 meta: %{},
                 changed_from: %{},
                 changed_to: %{},
                 user_id: nil,
                 team_id: nil,
                 datetime: %NaiveDateTime{}
               }
             ] = Repo.all(Audit.Entry)
    end

    test "persists full audit entry with change tracking" do
      user = new_user()
      changeset = Plausible.Auth.User.name_changeset(user, %{name: "John Doe"})

      Audit.new("test_entry",
        entity: Plausible.Auth.User,
        meta: %{foo: :bar},
        team_id: 232,
        user_id: 2323
      )
      |> Audit.track_changes(changeset)
      |> Audit.persist()

      assert [
               %Plausible.Audit.Entry{
                 id: _,
                 name: "test_entry",
                 entity: "Plausible.Auth.User",
                 entity_id: entity_id,
                 meta: %{"foo" => "bar"},
                 changed_from: %{"name" => "Jane Smith"},
                 changed_to: %{"name" => "John Doe"},
                 user_id: 2323,
                 team_id: 232,
                 datetime: %NaiveDateTime{}
               }
             ] = Repo.all(Audit.Entry)

      assert entity_id == to_string(user.id)
    end
  end

  describe "conn" do
    test "builds from conn" do
      conn =
        %Plug.Conn{}
        |> Plug.Conn.assign(:current_user, %Plausible.Auth.User{id: 77})
        |> Plug.Conn.assign(:current_team, %Plausible.Teams.Team{id: 78})

      assert %Plausible.Audit.Entry{user_id: 77, team_id: 78} = Audit.new("some_action", conn)
    end
  end
end
