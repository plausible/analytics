defmodule Plausible.OAuth.PKCETest do
  use ExUnit.Case, async: true

  alias Plausible.OAuth.PKCE

  defp challenge_for(verifier),
    do: :crypto.hash(:sha256, verifier) |> Base.url_encode64(padding: false)

  describe "verify/3" do
    test "accepts the worked example from RFC 7636 appendix B" do
      verifier = "dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk"
      challenge = "E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM"

      assert :ok = PKCE.verify(challenge, verifier, "S256")
    end

    test "accepts a matching S256 verifier" do
      verifier = :crypto.strong_rand_bytes(32) |> Base.url_encode64(padding: false)

      assert :ok = PKCE.verify(challenge_for(verifier), verifier, "S256")
    end

    test "rejects a mismatched verifier" do
      verifier = :crypto.strong_rand_bytes(32) |> Base.url_encode64(padding: false)

      assert {:error, :invalid_grant} =
               PKCE.verify(challenge_for(verifier), "mismatched-verifier", "S256")
    end

    test "rejects the plain method even when the values match" do
      assert {:error, :invalid_grant} = PKCE.verify("abc", "abc", "plain")
    end

    test "rejects a missing verifier" do
      verifier = :crypto.strong_rand_bytes(32) |> Base.url_encode64(padding: false)

      assert {:error, :invalid_grant} = PKCE.verify(challenge_for(verifier), nil, "S256")
    end

    test "accepts a verifier at both length bounds (RFC 7636 section 4.1)" do
      for length <- [43, 128] do
        verifier = String.duplicate("a", length)
        assert :ok = PKCE.verify(challenge_for(verifier), verifier, "S256")
      end
    end

    test "rejects a verifier outside the length bounds even though it hashes to the challenge" do
      for length <- [0, 42, 129] do
        verifier = String.duplicate("a", length)

        assert {:error, :invalid_grant} =
                 PKCE.verify(challenge_for(verifier), verifier, "S256")
      end
    end
  end
end
