defmodule Plausible.InstallationSupport.Checks.SnippetCacheBust do
  @moduledoc """
  A naive way of trying to figure out whether the latest site contents
  is wrapped with some CDN/caching layer.

  In case no snippets were found, we'll try to bust the cache by appending
  a random query parameter and re-run `FetchBody` and `Snippet` checks.
  If the result is different this time, we'll assume cache likely.
  """
  use Plausible.InstallationSupport.Check

  alias Plausible.InstallationSupport.{LegacyVerification, Checks, URL}

  @impl true
  def report_progress_as, do: "We're looking for the Plausible snippet on your site"

  @impl true
  def perform(
        %State{
          url: url,
          diagnostics: %LegacyVerification.Diagnostics{
            snippets_found_in_head: 0,
            snippets_found_in_body: 0,
            body_fetched?: true
          }
        } = state
      ) do
    state2 =
      %{state | url: URL.bust_url(url)}
      |> Checks.FetchBody.perform()
      |> Checks.ScanBody.perform()
      |> Checks.Snippet.perform()

    if state2.diagnostics.snippets_found_in_head > 0 or
         state2.diagnostics.snippets_found_in_body > 0 do
      put_diagnostics(state2, snippet_found_after_busting_cache?: true)
    else
      state
    end
  end

  def perform(state), do: state
end
