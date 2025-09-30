defmodule Plausible.InstallationSupport.Verification.Checks do
  @moduledoc """
  Checks that are performed during tracker script installation verification.

  In async execution, each check notifies the caller by sending a message to it.
  """
  alias Plausible.InstallationSupport.Verification
  alias Plausible.InstallationSupport.{State, CheckRunner, Checks}

  require Logger

  @checks [
    Checks.Url,
    Checks.InstallationV2,
    Checks.InstallationV2CacheBust
  ]

  @spec run(String.t(), String.t(), String.t(), Keyword.t()) :: :ok
  def run(url, data_domain, installation_type, opts \\ []) do
    report_to = Keyword.get(opts, :report_to, self())
    async? = Keyword.get(opts, :async?, true)
    slowdown = Keyword.get(opts, :slowdown, 500)

    init_state =
      %State{
        url: url,
        data_domain: data_domain,
        report_to: report_to,
        diagnostics: %Verification.Diagnostics{
          selected_installation_type: installation_type
        }
      }

    CheckRunner.run(init_state, @checks,
      async?: async?,
      report_to: report_to,
      slowdown: slowdown
    )
  end

  def interpret_diagnostics(%State{} = state) do
    Verification.Diagnostics.interpret(
      state.diagnostics,
      state.data_domain,
      state.url
    )
  end
end
