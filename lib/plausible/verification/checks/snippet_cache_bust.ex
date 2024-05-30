defmodule Plausible.Verification.Checks.SnippetCacheBust do
  @moduledoc """
  A naive way of trying to figure out whether the latest site contents 
  is wrapped with some CDN/caching layer.
  In case no snippets were found, we'll try to bust the cache by appending a random query parameter
  and re-run `Plausible.Verification.Checks.FetchBody` and `Plausible.Verification.Checks.Snippet` checks.
  If the result is different this time, we'll assume cache likely.
  """
  use Plausible.Verification.Check

  @impl true
  def report_progress_as, do: "We're looking for the Plausible snippet on your site"

  @impl true
  def perform(
        %State{
          url: url,
          diagnostics: %Diagnostics{
            snippets_found_in_head: 0,
            snippets_found_in_body: 0,
            body_fetched?: true
          }
        } = state
      ) do
    state2 =
      %{state | url: Plausible.Verification.URL.bust_url(url)}
      |> Plausible.Verification.Checks.FetchBody.perform()
      |> Plausible.Verification.Checks.ScanBody.perform()
      |> Plausible.Verification.Checks.Snippet.perform()

    if state2.diagnostics.snippets_found_in_head > 0 or
         state2.diagnostics.snippets_found_in_body > 0 do
      put_diagnostics(state2, snippet_found_after_busting_cache?: true)
    else
      state
    end
  end

  def perform(state), do: state
end
