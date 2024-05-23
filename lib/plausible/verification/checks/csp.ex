defmodule Plausible.Verification.Checks.CSP do
  @moduledoc """
  Scans the Content Security Policy header to ensure that the Plausible domain is allowed.
  See `Plausible.Verification.Checks` for the execution sequence.
  """
  use Plausible.Verification.Check

  @impl true
  def friendly_name, do: "We're visiting your site to ensure that everything is working correctly"

  @impl true
  def perform(%State{assigns: %{headers: headers}} = state) do
    case headers["content-security-policy"] do
      [policy] ->
        directives = String.split(policy, ";")

        allowed? =
          Enum.any?(directives, fn directive ->
            String.contains?(directive, PlausibleWeb.Endpoint.host())
          end)

        if allowed? do
          state
        else
          put_diagnostics(state, disallowed_via_csp?: true)
        end

      _ ->
        state
    end
  end

  def perform(state), do: state
end
