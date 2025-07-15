defmodule Plausible.InstallationSupport.Checks.CSPTest do
  use Plausible.DataCase, async: true

  alias Plausible.InstallationSupport.{State, LegacyVerification}

  @check Plausible.InstallationSupport.Checks.CSP
  @default_state %State{diagnostics: %LegacyVerification.Diagnostics{}}

  test "skips no headers" do
    state = @default_state
    assert ^state = @check.perform(state)
  end

  test "skips no headers 2" do
    state = @default_state |> State.assign(headers: %{})
    assert ^state = @check.perform(state)
  end

  test "disallowed" do
    headers = %{"content-security-policy" => ["default-src 'self' foo.local; example.com"]}

    state =
      @default_state
      |> State.assign(headers: headers)
      |> @check.perform()

    assert state.diagnostics.disallowed_via_csp?
  end

  test "allowed" do
    headers = %{"content-security-policy" => ["default-src 'self' example.com; localhost"]}

    state =
      @default_state
      |> State.assign(headers: headers)
      |> @check.perform()

    refute state.diagnostics.disallowed_via_csp?
  end
end
