defmodule Plausible.Auth.DisposableEmailTest do
  use ExUnit.Case, async: true
  use Plausible

  @moduletag :ee_only

  on_ee do
    alias Plausible.Auth.DisposableEmail

    # The test domains below are added to the list in `config/test.exs`, so these
    # tests don't break when the vendored list is refreshed.
    describe "disposable?/1" do
      test "loads the vendored list" do
        assert DisposableEmail.domains_count() > 500
      end

      test "true for an address on a listed domain" do
        assert DisposableEmail.disposable?("someone@disposable.test")
      end

      test "ignores case and surrounding whitespace in the domain" do
        assert DisposableEmail.disposable?("Someone@DISPOSABLE.test")
        assert DisposableEmail.disposable?("someone@disposable.test ")
        assert DisposableEmail.disposable?("someone@disposable.test.")
      end

      test "false for regular and freemail providers" do
        refute DisposableEmail.disposable?("someone@gmail.com")
        refute DisposableEmail.disposable?("someone@outlook.com")
        refute DisposableEmail.disposable?("someone@proton.me")
        refute DisposableEmail.disposable?("someone@plausible.io")
      end

      test "only matches the exact domain, not the local part or related domains" do
        refute DisposableEmail.disposable?("disposable.test@gmail.com")
        refute DisposableEmail.disposable?("someone@disposable.test.example.com")
        refute DisposableEmail.disposable?("someone@x7q-unlisted.disposable.test")
      end

      test "matches the Unicode form of a listed internationalized domain" do
        # Listed as xn--dispsable-86a.test and xn--80aafgq8afccr4o.test
        assert DisposableEmail.disposable?("someone@xn--dispsable-86a.test")
        assert DisposableEmail.disposable?("someone@dispósable.test")
        assert DisposableEmail.disposable?("someone@DISPÓSABLE.TEST")
        assert DisposableEmail.disposable?("someone@одноразовая.test")
      end

      test "matches Unicode lookalike spellings of a listed ASCII domain" do
        # fullwidth letters
        assert DisposableEmail.disposable?("someone@ｄｉｓｐｏｓａｂｌｅ.test")
        # ideographic full stop in place of the dot
        assert DisposableEmail.disposable?("someone@disposable。test")
      end

      test "false for input that is not an address" do
        refute DisposableEmail.disposable?("")
        refute DisposableEmail.disposable?("disposable.test")
        refute DisposableEmail.disposable?(nil)
      end
    end
  end
end
