defmodule Plausible.InstallationSupport.Checks.VerifyInstallationCacheBust do
  @moduledoc """
  If the output of previous checks can not be interpreted as successful,
  as a last resort, we try to bust the cache of the site under test by adding a query parameter to the URL,
  and running VerifyInstallation again.

  Whatever the result from the rerun, that is what we use to interpret the installation.

  The idea is to make sure that any issues we detect will be about the latest version of their website.

  We also want to avoid reporting a successful installation if it took a special cache-busting action to make it work.
  """

  require Logger
  alias Plausible.InstallationSupport
  use Plausible.InstallationSupport.Check

  @impl true
  def report_progress_as, do: "We're verifying that your visitors are being counted correctly"

  @impl true
  def perform(%State{url: url} = state) do
    case InstallationSupport.Verification.Checks.interpret_diagnostics(state, telemetry?: false) do
      %InstallationSupport.Result{ok?: true} ->
        state

      %InstallationSupport.Result{data: %{unhandled: true}} ->
        state

      _known_installation_failure ->
        reset_diagnostics = %InstallationSupport.Verification.Diagnostics{
          selected_installation_type: state.diagnostics.selected_installation_type
        }

        state
        |> struct!(diagnostics: reset_diagnostics)
        |> struct!(url: InstallationSupport.URL.bust_url(url))
        |> InstallationSupport.Checks.VerifyInstallation.perform()
        |> put_diagnostics(diagnostics_are_from_cache_bust: true)
    end
  end
end
