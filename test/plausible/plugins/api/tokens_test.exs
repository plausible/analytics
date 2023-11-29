defmodule Plausible.Plugins.API.TokensTest do
  use Plausible.DataCase, async: true

  alias Plausible.Plugins.API.Token
  alias Plausible.Plugins.API.Tokens
  alias Plausible.Repo

  describe "create/2" do
    test "generates and stores the token" do
      site = insert(:site)
      assert {:ok, %Token{} = token, raw} = Tokens.create(site, "My test token")

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

  describe "any?/2" do
    test "returns if a site has any tokens" do
      site1 = insert(:site, domain: "foo1.example.com")
      site2 = insert(:site, domain: "foo2.example.com")
      assert Tokens.any?(site1) == false
      assert Tokens.any?(site2) == false
      assert {:ok, _, _} = Tokens.create(site1, "My test token")
      assert Tokens.any?(site1) == true
      assert Tokens.any?(site2) == false
    end
  end

  describe "delete/2" do
    test "deletes a token" do
      site1 = insert(:site, domain: "foo1.example.com")
      site2 = insert(:site, domain: "foo2.example.com")

      assert {:ok, t1, _} = Tokens.create(site1, "My test token")
      assert {:ok, t2, _} = Tokens.create(site1, "My test token")
      assert {:ok, _, _} = Tokens.create(site2, "My test token")

      :ok = Tokens.delete(site1, t1.id)
      # idempotent
      :ok = Tokens.delete(site1, t1.id)

      assert Tokens.any?(site1)
      :ok = Tokens.delete(site1, t2.id)
      refute Tokens.any?(site1)

      assert Tokens.any?(site2)
    end
  end

  describe "update_last_seen/1" do
    test "updates in 5m window" do
      site = insert(:site)
      assert {:ok, token0, _} = Tokens.create(site, "My test token")

      now = NaiveDateTime.utc_now()

      {:ok, token1} = Tokens.update_last_seen(token0, now)
      {:ok, token2} = Tokens.update_last_seen(token1, Timex.shift(now, minutes: 2))

      assert token1.last_used_at == token2.last_used_at

      {:ok, token3} = Tokens.update_last_seen(token2, Timex.shift(now, minutes: 6))

      assert NaiveDateTime.compare(token3.last_used_at, token2.last_used_at) == :gt
    end
  end
end
