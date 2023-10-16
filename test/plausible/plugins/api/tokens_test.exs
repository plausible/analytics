defmodule Plausible.Plugins.API.TokensTest do
  use Plausible.DataCase, async: true

  alias Plausible.Plugins.API.Token
  alias Plausible.Plugins.API.Tokens
  alias Plausible.Repo

  describe "create/2" do
    test "generates and stores the token" do
      site = insert(:site)
      assert {:ok, %Token{} = token, raw} = Tokens.create(site, "My test token")
      assert <<"plausible-plugin-test-", _::binary-size(40)>> = raw

      from_db = Repo.get(Token, token.id)

      assert from_db.token_hash == token.token_hash
      assert from_db.description == "My test token"
      assert from_db.site_id == site.id
      hint = from_db.hint
      assert is_binary(hint) and byte_size(hint) == 4
      assert String.ends_with?(raw, hint)
    end

    test "fails to store on input errors" do
      site = insert(:site)
      assert {:error, %Ecto.Changeset{}} = Tokens.create(site, nil)
    end
  end

  describe "find/2" do
    test "finds the right token" do
      site = insert(:site)
      assert {:ok, _, raw} = Tokens.create(site, "My test token")
      assert {:ok, found} = Tokens.find(raw)
      assert found.id == found.id
      assert found.site_id == site.id
    end

    test "fails to find the token" do
      assert {:error, :not_found} = Tokens.find("non-existing")
    end
  end
end
