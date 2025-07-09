defmodule Plausible.AuditTest do
  use Plausible.DataCase

  use Plausible.Teams.Test

  alias Plausible.Audit
  alias Plausible.Audit.Encoder
  alias Plausible.Audit.Entry
  alias Plausible.Audit.TestSchema

  describe "Audit.Encoder" do
    test "encodes integer, float, and bitstring as themselves" do
      assert Encoder.encode(42) == 42
      assert Encoder.encode(3.14) == 3.14
      assert Encoder.encode("hello") == "hello"
    end

    test "encodes atoms" do
      assert Encoder.encode(:foo) == "foo"
      assert Encoder.encode(nil) == nil
      assert Encoder.encode(true) == true
      assert Encoder.encode(false) == false
    end

    test "encodes Date, DateTime, NaiveDateTime, Time as strings" do
      dt = ~U[2024-06-01 12:00:00Z]
      date = ~D[2024-06-01]
      ndt = ~N[2024-06-01 12:00:00]
      time = ~T[12:00:00]
      assert Encoder.encode(dt) == to_string(dt)
      assert Encoder.encode(date) == to_string(date)
      assert Encoder.encode(ndt) == to_string(ndt)
      assert Encoder.encode(time) == to_string(time)
    end

    test "encodes lists recursively" do
      assert Encoder.encode([:foo, 1, "bar"]) == ["foo", 1, "bar"]
    end

    test "encodes map recursively" do
      map = %{foo: :bar, num: 1, nested: %{baz: :qux}}
      assert Encoder.encode(map) == %{foo: "bar", num: 1, nested: %{baz: "qux"}}
    end

    test "raises if association not loaded and not allowed" do
      map = %{
        assoc: %Ecto.Association.NotLoaded{
          __field__: :assoc,
          __owner__: DummyStruct,
          __cardinality__: :one
        },
        __allow_not_loaded__: []
      }

      assert_raise Audit.EncoderError, ~r/assoc association not loaded/, fn ->
        Encoder.encode(map)
      end
    end

    test "skips not loaded association if allowed" do
      map = %{
        assoc: %Ecto.Association.NotLoaded{
          __field__: :assoc,
          __owner__: DummyStruct,
          __cardinality__: :one
        },
        __allow_not_loaded__: [:assoc]
      }

      assert Encoder.encode(map) == %{}
    end

    test "enforcing schema association present" do
      assert_raise Audit.EncoderError, fn ->
        Audit.encode(%TestSchema.VariantWithAssociation{id: 1})
      end

      assert %{id: 1, team: "some"} =
               Audit.encode(%TestSchema.VariantWithAssociation{id: 1, team: :some})

      assert %{id: 1} =
               Audit.encode(%TestSchema.VariantWithAssociationAllowNotLoaded{id: 1})

      assert %{id: 1, team: "some"} =
               Audit.encode(%TestSchema.VariantWithAssociationAllowNotLoaded{id: 1, team: :some})
    end

    test "returns data if only data is present" do
      data = %{foo: :bar}
      changeset = %Ecto.Changeset{data: data, changes: %{}}
      assert Encoder.encode(changeset) == %{foo: "bar"}
    end

    test "returns changes if only changes are present" do
      changes = %{foo: :baz}
      changeset = %Ecto.Changeset{data: %{}, changes: changes}
      assert Encoder.encode(changeset) == %{foo: "baz"}
    end

    test "returns empty map if both data and changes are empty" do
      changeset = %Ecto.Changeset{data: %{}, changes: %{}}
      assert Encoder.encode(changeset) == %{}
    end

    test "returns before/after map if both data and changes are present" do
      data = %{foo: :bar}
      changes = %{foo: :baz}
      changeset = %Ecto.Changeset{data: data, changes: changes}
      assert Encoder.encode(changeset) == %{before: %{foo: "bar"}, after: %{foo: "baz"}}
    end

    test "raises if encoder is not derived for a struct" do
      struct = %{__struct__: Foo, foo: 1, bar: 2}

      assert_raise Protocol.UndefinedError, fn ->
        Encoder.encode(struct)
      end
    end
  end

  describe "Audit.Entry" do
    test "changeset/2 with valid params and context" do
      Entry.set_context(%{current_user: %{id: 42}, current_team: %{id: 7}})
      params = %{entity: "User", entity_id: "42", meta: %{name: "bar"}}
      cs = Entry.changeset("login", params)
      assert cs.valid?
      assert cs.data.name == "login"
      assert cs.changes.entity == "User"
      assert cs.changes.entity_id == "42"
      assert cs.changes.meta == %{name: "bar"}
      assert cs.changes.user_id == 42
      assert cs.changes.team_id == 7
      assert is_struct(cs.changes.datetime, NaiveDateTime)
    end

    test "changeset/2 missing required fields" do
      cs = Entry.changeset("test", %{})
      refute cs.valid?

      assert cs.errors == [
               entity: {"can't be blank", [validation: :required]},
               entity_id: {"can't be blank", [validation: :required]}
             ]
    end

    test "changeset/2 with missing context" do
      cs = Entry.changeset("test", %{entity: "E", entity_id: "1"})
      assert is_nil(cs.changes.user_id)
      assert is_nil(cs.changes.team_id)
      assert cs.data.user_id == 0
      assert cs.data.team_id == 0
    end

    test "new/3 with struct and params" do
      Entry.set_context(%{current_user: %{id: 1}, current_team: %{id: 2}})
      struct = %TestSchema{id: 123}
      cs = Entry.new("test", struct, %{meta: %{x: 1}})
      assert cs.changes.entity == "Plausible.Audit.TestSchema"
      assert cs.changes.entity_id == "123"
      assert cs.changes.meta == %{x: 1}
    end

    test "name/4 with binary entity and entity_id" do
      cs = Entry.name("name", "Bar", "99", %{meta: %{a: 1}})
      assert cs.changes.entity == "Bar"
      assert cs.changes.entity_id == "99"
      assert cs.changes.meta == %{a: 1}
    end

    test "include_change/2 encodes changeset" do
      struct = %TestSchema{id: 1, name: "bar"}
      changeset = Ecto.Changeset.change(struct, name: "baz")

      entry = Entry.new("update", struct)
      entry = Entry.include_change(entry, changeset)
      assert entry.changes.change == %{after: %{name: "baz"}, before: %{id: 1, name: "bar"}}
    end
  end

  describe "Repo integration" do
    test "update_with_audit/2" do
      user = new_user() |> Repo.preload([:sso_integration, :sso_domain])

      cs = Plausible.Auth.User.name_changeset(user, %{name: "John Doe"})

      assert {:ok, %Plausible.Auth.User{name: "John Doe"}} =
               Repo.update_with_audit(cs, "user_update")

      assert [
               %Plausible.Audit.Entry{
                 name: "user_update",
                 change: %{
                   "after" => %{"name" => "John Doe"},
                   "before" => %{
                     "name" => "Jane Smith"
                   }
                 }
               }
             ] = Audit.list_entries(entity: "Plausible.Auth.User", entity_id: "#{user.id}")
    end
  end

  test "update_with_audit!/2" do
    user = new_user() |> Repo.preload([:sso_integration, :sso_domain])
    cs = Plausible.Auth.User.name_changeset(user, %{name: "John Doe"})

    assert %Plausible.Auth.User{name: "John Doe"} =
             Repo.update_with_audit!(cs, "user_update")

    assert [
             %Plausible.Audit.Entry{
               name: "user_update",
               change: %{
                 "after" => %{"name" => "John Doe"},
                 "before" => %{
                   "name" => "Jane Smith"
                 }
               }
             }
           ] = Audit.list_entries(entity: "Plausible.Auth.User", entity_id: "#{user.id}")
  end

  test "insert_with_audit/2" do
    changeset =
      Plausible.Auth.User.new(%{
        name: "Jane Doe",
        email: "jane@example.com",
        password: "very-secret-and-very-long-123",
        password_confirmation: "very-secret-and-very-long-123"
      })

    {:ok, %Plausible.Auth.User{name: "Jane Doe"} = user} =
      Repo.insert_with_audit(changeset, "user_insert")

    assert [
             %Plausible.Audit.Entry{
               name: "user_insert",
               change: %{}
             }
           ] = Audit.list_entries(entity: "Plausible.Auth.User", entity_id: "#{user.id}")
  end

  test "insert_with_audit!/2" do
    changeset =
      Plausible.Auth.User.new(%{
        name: "Jane Doe",
        email: "jane@example.com",
        password: "very-secret-and-very-long-123",
        password_confirmation: "very-secret-and-very-long-123"
      })

    assert %Plausible.Auth.User{name: "Jane Doe", id: user_id} =
             Repo.insert_with_audit!(changeset, "user_insert")

    assert [
             %Plausible.Audit.Entry{
               name: "user_insert",
               change: %{}
             }
           ] = Audit.list_entries(entity: "Plausible.Auth.User", entity_id: "#{user_id}")
  end

  test "delete_with_audit!/2" do
    user = new_user()
    assert %Plausible.Auth.User{} = Repo.delete_with_audit!(user, "user_delete")

    assert [
             %Plausible.Audit.Entry{
               name: "user_delete",
               change: %{}
             }
           ] = Audit.list_entries(entity: "Plausible.Auth.User", entity_id: "#{user.id}")
  end
end
