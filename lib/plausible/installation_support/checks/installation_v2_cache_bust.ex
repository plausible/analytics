defmodule Plausible.InstallationSupport.Checks.InstallationV2CacheBust do
  require Logger
  alias Plausible.InstallationSupport
  use Plausible.InstallationSupport.Check

  @impl true
  def report_progress_as, do: "We're verifying that your visitors are being counted correctly"

  @impl true
  def perform(%State{url: url} = state) do
    if InstallationSupport.Verification.Checks.interpret_diagnostics(state) ==
         %InstallationSupport.Result{ok?: true} do
      state
    else
      url_that_maybe_busts_cache =
        Plausible.InstallationSupport.URL.bust_url(url)

      state2 =
        Plausible.InstallationSupport.Checks.InstallationV2.perform(%{
          state
          | url: url_that_maybe_busts_cache
        })

      put_diagnostics(state2, diagnostics_are_from_cache_bust: true)
    end
  end
end
