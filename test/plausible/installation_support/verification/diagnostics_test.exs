defmodule Plausible.InstallationSupport.Verification.DiagnosticsTest do
  use ExUnit.Case, async: true

  alias Plausible.InstallationSupport.Verification.Diagnostics.Error

  describe "Error.new!/1" do
    test "accepts a recommendation whose inline_links text appears exactly once" do
      assert %Error{} =
               Error.new!(%{
                 message: "Something went wrong",
                 recommendation: "Check the docs for more info",
                 inline_links: [%{text: "docs", href: "https://plausible.io/docs"}]
               })
    end

    test "raises when inline_links text isn't found in the recommendation" do
      assert_raise ArgumentError, ~r/must appear exactly once/, fn ->
        Error.new!(%{
          message: "Something went wrong",
          recommendation: "Check the manual for more info",
          inline_links: [%{text: "docs", href: "https://plausible.io/docs"}]
        })
      end
    end

    test "raises when inline_links text appears more than once in the recommendation" do
      assert_raise ArgumentError, ~r/must appear exactly once/, fn ->
        Error.new!(%{
          message: "Something went wrong",
          recommendation: "Check the docs, or check the docs again",
          inline_links: [%{text: "the docs", href: "https://plausible.io/docs"}]
        })
      end
    end

    test "raises when inline_links href doesn't point at plausible.io" do
      assert_raise ArgumentError, ~r/must start with/, fn ->
        Error.new!(%{
          message: "Something went wrong",
          recommendation: "Check the docs for more info",
          inline_links: [%{text: "docs", href: "https://example.com/docs"}]
        })
      end
    end
  end
end
