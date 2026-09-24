defmodule Plausible.OAuth.TokenTest do
  use ExUnit.Case, async: false
  use Plausible.TestUtils

  import Plausible.AssertMatches

  alias Plausible.OAuth.Token

  describe "generate/1" do
    test "returns a prefixed raw value with its hash and displayable hint" do
      token = Token.generate(:access)

      assert_matches ^strict_map(%{
                       raw:
                         ^any(
                           :string,
                           &String.starts_with?(&1, Token.plaintext_prefix(:access) <> "-")
                         ),
                       hash: ^Token.hash(token.raw),
                       hint: ^any(:string)
                     }) = token
    end

    test "hints at the tail of the raw value, past the constant prefix" do
      token = Token.generate(:access)

      assert byte_size(token.hint) == 4
      assert String.ends_with?(token.raw, token.hint)
    end

    test "returns a different value every time" do
      refute Token.generate(:access).raw == Token.generate(:access).raw
    end
  end

  describe "prefix/1" do
    @tag :ee_only
    test "identifies the kind of value" do
      patch_env(:environment, "prod")

      assert Token.plaintext_prefix(:access) == "plausible-oauth-at"
      assert Token.plaintext_prefix(:refresh) == "plausible-oauth-rt"
      assert Token.plaintext_prefix(:code) == "plausible-oauth-ac"
    end

    @tag :ee_only
    test "spells out the environment outside prod" do
      assert Token.plaintext_prefix(:access) == "plausible-oauth-at-test"
    end

    @tag :ce_build_only
    test "marks self-hosted builds" do
      assert Token.plaintext_prefix(:access) == "plausible-oauth-at-selfhost"
    end
  end
end
