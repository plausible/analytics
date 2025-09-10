defmodule Plausible.Plugins.API.TokenTest do
  use Plausible.DataCase, async: false

  alias Plausible.Plugins.API.Token

  @tag :ee_only
  test "basic token properties" do
    t1 = Token.generate()
    t2 = Token.generate()

    assert is_binary(t1.raw)
    assert is_binary(t1.hash)

    assert is_binary(t2.raw)
    assert is_binary(t2.hash)

    assert byte_size(t1.hash) == 32
    assert byte_size(t2.hash) == 32

    assert <<"plausible-plugin-test-", _::binary-size(40)>> = t1.raw
    assert <<"plausible-plugin-test-", _::binary-size(40)>> = t2.raw

    assert t1.raw != t2.raw
    assert t1.hash != t2.hash
  end

  describe "prefix/0" do
    @tag :ee_only
    test "default prefix - full build" do
      assert Token.prefix() == "plausible-plugin-test"
    end

    @tag :ce_build_only
    test "selfhosted prefix" do
      assert Token.prefix() == "plausible-plugin-selfhost"
    end

    @tag :ee_only
    test "prod prefix" do
      patch_env(:environment, "prod")
      assert Token.prefix() == "plausible-plugin"
    end

    @tag :ee_only
    test "staging prefix" do
      patch_env(:environment, "staging")
      assert Token.prefix() == "plausible-plugin-staging"
    end
  end

  describe "insert_changeset/2" do
    test "required fields" do
      changeset = Token.insert_changeset(nil, %{raw: "", hash: ""}, %{})
      refute changeset.valid?

      assert [
               description: {"can't be blank", _},
               site: {"can't be blank", _},
               token_hash: {"can't be blank", _},
               hint: {"can't be blank", _}
             ] = changeset.errors
    end

    test "valid changeset" do
      site = build(:site, id: 1_892_787)

      changeset =
        Token.insert_changeset(site, Token.generate(), %{
          "description" => "My token"
        })

      assert changeset.valid?

      assert Ecto.Changeset.get_field(changeset, :site).id == 1_892_787
    end
  end

  test "last_used_humanize/1" do
    now = NaiveDateTime.utc_now()

    last_seen = fn shift ->
      Token.last_used_humanize(%Token{last_used_at: NaiveDateTime.shift(now, shift)})
    end

    assert Token.last_used_humanize(%Token{}) == "Not yet"

    assert last_seen.(minute: -1) == "Just recently"
    assert last_seen.(minute: -4) == "Just recently"
    assert last_seen.(minute: -6) == "Several minutes ago"
    assert last_seen.(hour: -1) == "An hour ago"
    assert last_seen.(hour: -7) == "Hours ago"
    assert last_seen.(day: -1) == "Yesterday"
    assert last_seen.(day: -3) == "Sometime this week"
    assert last_seen.(month: -1) == "Long time ago"
  end
end
