defmodule Plausible.Verification.Checks.CSPTest do
  use Plausible.DataCase, async: true

  alias Plausible.Verification.State

  @check Plausible.Verification.Checks.CSP

  test "skips no headers" do
    state = %State{}
    assert ^state = @check.perform(state)
  end

  test "skips no headers 2" do
    state = %State{} |> State.assign(headers: %{})
    assert ^state = @check.perform(state)
  end

  test "disallowed" do
    headers = %{"content-security-policy" => ["default-src 'self' foo.local; example.com"]}

    state =
      %State{}
      |> State.assign(headers: headers)
      |> @check.perform()

    assert state.diagnostics.disallowed_via_csp?
  end

  test "allowed" do
    headers = %{"content-security-policy" => ["default-src 'self' example.com; localhost"]}

    state =
      %State{}
      |> State.assign(headers: headers)
      |> @check.perform()

    refute state.diagnostics.disallowed_via_csp?
  end
end
