defmodule Plausible.Plugins.API.TokenTest do
  use Plausible.DataCase, async: false

  alias Plausible.Plugins.API.Token

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
    test "default prefix" do
      assert Token.prefix() == "plausible-plugin-test"
    end

    test "selfhosted prefix" do
      patch_env(:is_selfhost, true)
      assert Token.prefix() == "plausible-plugin-selfhost"
    end

    test "prod prefix" do
      patch_env(:environment, "prod")
      assert Token.prefix() == "plausible-plugin"
    end

    test "staging prefix" do
      patch_env(:environment, "staging")
      assert Token.prefix() == "plausible-plugin-staging"
    end
  end

  describe "insert_changeset/2" do
    test "required fields" do
      changeset = Token.insert_changeset(nil, %{})
      refute changeset.valid?

      assert [
               token_hash: {"can't be blank", _},
               description: {"can't be blank", _},
               site: {"can't be blank", _}
             ] = changeset.errors
    end

    test "valid changeset" do
      site = build(:site, id: 1_892_787)

      changeset =
        Token.insert_changeset(site, %{
          "description" => "My token",
          "token_hash" => Token.generate().hash
        })

      assert changeset.valid?

      assert Ecto.Changeset.get_field(changeset, :site).id == 1_892_787
    end
  end
end
