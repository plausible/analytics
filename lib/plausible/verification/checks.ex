defmodule Plausible.Verification.Checks do
  @moduledoc """
  Checks that are performed during site verification.
  Each module defined in `@checks` implements the `Plausible.Verification.Check` behaviour.
  Checks are normally run asynchronously, except when synchronous execution is optionally required
  for tests. Slowdowns can be optionally added, the user doesn't benefit from running the checks too quickly.

  In async execution, each check notifies the caller by sending a message to it.
  """
  alias Plausible.Verification.Checks
  alias Plausible.Verification.State

  require Logger

  @checks [
    Checks.FetchBody,
    Checks.CSP,
    Checks.ScanBody,
    Checks.Snippet,
    Checks.SnippetCacheBust,
    Checks.Installation
  ]

  def run(url, data_domain, opts \\ []) do
    checks = Keyword.get(opts, :checks, @checks)
    report_to = Keyword.get(opts, :report_to, self())
    async? = Keyword.get(opts, :async?, true)
    slowdown = Keyword.get(opts, :slowdown, 500)

    if async? do
      Task.start_link(fn -> do_run(url, data_domain, checks, report_to, slowdown) end)
    else
      do_run(url, data_domain, checks, report_to, slowdown)
    end
  end

  def interpret_diagnostics(%State{} = state) do
    Plausible.Verification.Diagnostics.rate(state.diagnostics, state.url)
  end

  defp do_run(url, data_domain, checks, report_to, slowdown) do
    init_state = %State{url: url, data_domain: data_domain, report_to: report_to}

    state =
      Enum.reduce(
        checks,
        init_state,
        fn check, state ->
          state
          |> State.notify_start(check, slowdown)
          |> check.perform_wrapped()
        end
      )

    State.notify_verification_end(state, slowdown)
  end
end
