defmodule Plausible.InstallationSupport.Detection.Checks do
  @moduledoc """
  Checks that are performed during tracker script installation verification.

  In async execution, each check notifies the caller by sending a message to it.
  """
  alias Plausible.InstallationSupport.Detection
  alias Plausible.InstallationSupport.{State, CheckRunner, Checks}

  require Logger

  @checks [
    Checks.Url,
    Checks.Detection
  ]

  def run(url, data_domain, opts \\ []) do
    checks = Keyword.get(opts, :checks, @checks)
    report_to = Keyword.get(opts, :report_to, self())
    async? = Keyword.get(opts, :async?, true)
    slowdown = Keyword.get(opts, :slowdown, 500)
    detect_v1? = Keyword.get(opts, :detect_v1?, false)

    init_state =
      %State{
        url: url,
        data_domain: data_domain,
        report_to: report_to,
        diagnostics: %Detection.Diagnostics{},
        assigns: %{detect_v1?: detect_v1?}
      }

    CheckRunner.run(init_state, checks,
      async?: async?,
      report_to: report_to,
      slowdown: slowdown
    )
  end

  def interpret_diagnostics(%State{} = state) do
    Detection.Diagnostics.interpret(
      state.diagnostics,
      state.url
    )
  end
end
