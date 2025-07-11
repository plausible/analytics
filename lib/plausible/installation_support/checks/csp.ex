defmodule Plausible.InstallationSupport.Checks.CSP do
  @moduledoc """
  Scans the Content Security Policy header to ensure that the Plausible domain is allowed.
  See `Plausible.InstallationSupport.LegacyVerification.Checks` for the execution sequence.
  """
  use Plausible.InstallationSupport.Check

  @impl true
  def report_progress_as, do: "We're visiting your site to ensure that everything is working"

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
