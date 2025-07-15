defmodule Plausible.InstallationSupport.LegacyVerification.Checks do
  @moduledoc """
  Checks that are performed during v1 site verification.

  In async execution, each check notifies the caller by sending a message to it.
  """
  alias Plausible.InstallationSupport.LegacyVerification
  alias Plausible.InstallationSupport.{State, CheckRunner, Checks}

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

    init_state =
      %State{
        url: url,
        data_domain: data_domain,
        report_to: report_to,
        diagnostics: %LegacyVerification.Diagnostics{}
      }

    CheckRunner.run(init_state, checks,
      async?: async?,
      report_to: report_to,
      slowdown: slowdown
    )
  end

  def interpret_diagnostics(%State{} = state) do
    LegacyVerification.Diagnostics.interpret(
      state.diagnostics,
      state.url
    )
  end
end
