defmodule Plausible.InstallationSupport.Checks.InstallationV2CacheBust do
  @moduledoc """
  If the output of previous checks can not be interpreted as successful,
  as a last resort, we try to bust the cache of the site under test by adding a query parameter to the URL,
  and running InstallationV2 again.

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
    if InstallationSupport.Verification.Checks.interpret_diagnostics(state) ==
         %InstallationSupport.Result{ok?: true} do
      state
    else
      url_that_maybe_busts_cache =
        Plausible.InstallationSupport.URL.bust_url(url)

      state_after_cache_bust =
        Plausible.InstallationSupport.Checks.InstallationV2.perform(%{
          state
          | url: url_that_maybe_busts_cache
        })

      put_diagnostics(state_after_cache_bust, diagnostics_are_from_cache_bust: true)
    end
  end
end
