defmodule Plausible.Verification.Checks.ScanBodyTest do
  use Plausible.DataCase, async: true

  alias Plausible.Verification.State

  @check Plausible.Verification.Checks.ScanBody

  test "skips on no raw body" do
    state = %State{}
    assert ^state = @check.perform(state)
  end

  test "detects nothing" do
    state =
      %State{}
      |> State.assign(raw_body: "...")
      |> @check.perform()

    refute state.diagnostics.gtm_likely?
    refute state.diagnostics.wordpress_likely?
  end

  for signature <- ["gtm.js", "googletagmanager.com"] do
    test "detects GTM: #{signature}" do
      state =
        %State{}
        |> State.assign(raw_body: "...#{unquote(signature)}...")
        |> @check.perform()

      assert state.diagnostics.gtm_likely?
      refute state.diagnostics.wordpress_likely?
    end
  end

  for signature <- ["wp-content", "wp-includes", "wp-json"] do
    test "detects WordPress: #{signature}" do
      state =
        %State{}
        |> State.assign(raw_body: "...#{unquote(signature)}...")
        |> @check.perform()

      refute state.diagnostics.gtm_likely?
      assert state.diagnostics.wordpress_likely?
    end
  end

  test "detects GTM and WordPress" do
    state =
      %State{}
      |> State.assign(raw_body: "...gtm.js....wp-content...")
      |> @check.perform()

    assert state.diagnostics.gtm_likely?
    assert state.diagnostics.wordpress_likely?
  end
end
