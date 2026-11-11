defmodule Plausible.Auth.DisposableEmailTest do
  use ExUnit.Case, async: true
  use Plausible

  @moduletag :ee_only

  on_ee do
    alias Plausible.Auth.DisposableEmail

    describe "disposable?/1" do
      test "true for an address on a listed domain" do
        assert DisposableEmail.disposable?("someone@mailinator.com")
        assert DisposableEmail.disposable?("someone@guerrillamail.com")
      end

      test "ignores case and surrounding whitespace in the domain" do
        assert DisposableEmail.disposable?("Someone@MAILINATOR.com")
        assert DisposableEmail.disposable?("someone@mailinator.com ")
        assert DisposableEmail.disposable?("someone@mailinator.com.")
      end

      test "false for regular and freemail providers" do
        refute DisposableEmail.disposable?("someone@gmail.com")
        refute DisposableEmail.disposable?("someone@outlook.com")
        refute DisposableEmail.disposable?("someone@proton.me")
        refute DisposableEmail.disposable?("someone@plausible.io")
      end

      test "only matches the exact domain, not the local part or related domains" do
        refute DisposableEmail.disposable?("mailinator.com@gmail.com")
        refute DisposableEmail.disposable?("someone@mailinator.com.example.com")
        refute DisposableEmail.disposable?("someone@x7q-unlisted.mailinator.com")
      end

      test "matches the Unicode form of a listed internationalized domain" do
        # Listed as account.xn--yaho-sqa.com and xn----7sba2bgi3agqk.xn--p1ai
        assert DisposableEmail.disposable?("someone@account.xn--yaho-sqa.com")
        assert DisposableEmail.disposable?("someone@account.yahóo.com")
        assert DisposableEmail.disposable?("someone@ACCOUNT.YAHÓO.COM")
        assert DisposableEmail.disposable?("someone@скала-уфмс.рф")
      end

      test "matches Unicode lookalike spellings of a listed ASCII domain" do
        # fullwidth letters
        assert DisposableEmail.disposable?("someone@ｍａｉｌｉｎａｔｏｒ.com")
        # ideographic full stop in place of the dot
        assert DisposableEmail.disposable?("someone@mailinator。com")
      end

      test "false for input that is not an address" do
        refute DisposableEmail.disposable?("")
        refute DisposableEmail.disposable?("mailinator.com")
        refute DisposableEmail.disposable?(nil)
      end
    end
  end
end
