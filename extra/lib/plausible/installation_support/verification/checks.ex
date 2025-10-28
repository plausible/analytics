defmodule Plausible.InstallationSupport.Verification.Checks do
  @moduledoc """
  Checks that are performed during tracker script installation verification.

  In async execution, each check notifies the caller by sending a message to it.
  """
  alias Plausible.InstallationSupport.Verification
  alias Plausible.InstallationSupport.{State, CheckRunner, Checks}

  require Logger

  @verify_installation_check_timeout 20_000

  @spec run(String.t(), String.t(), String.t(), Keyword.t()) :: {:ok, pid()} | State.t()
  def run(url, data_domain, installation_type, opts \\ []) do
    # Timeout option for testing purposes
    verify_installation_check_timeout =
      case Keyword.get(opts, :verify_installation_check_timeout) do
        int when is_integer(int) -> int
        _ -> @verify_installation_check_timeout
      end

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

    checks = [
      {Checks.Url, []},
      {Checks.VerifyInstallation, [timeout: verify_installation_check_timeout]},
      {Checks.VerifyInstallationCacheBust, [timeout: verify_installation_check_timeout]}
    ]

    CheckRunner.run(init_state, checks,
      async?: async?,
      report_to: report_to,
      slowdown: slowdown
    )
  end

  def telemetry_event_handled(), do: [:plausible, :verification, :handled]
  def telemetry_event_unhandled(), do: [:plausible, :verification, :unhandled]

  def interpret_diagnostics(
        %State{
          diagnostics: diagnostics,
          data_domain: data_domain,
          url: url
        },
        opts \\ []
      ) do
    telemetry? = Keyword.get(opts, :telemetry?, true)

    result =
      Verification.Diagnostics.interpret(
        diagnostics,
        data_domain,
        url
      )

    case {telemetry?, result.data} do
      {false, _} ->
        :skip

      {_, %{unhandled: true, browserless_issue: browserless_issue}} ->
        sentry_msg =
          if browserless_issue,
            do: "Browserless failure in verification",
            else: "Unhandled case for site verification"

        Sentry.capture_message(sentry_msg,
          extra: %{
            message: inspect(diagnostics),
            url: url,
            hash: :erlang.phash2(diagnostics)
          }
        )

        Logger.warning(
          "[VERIFICATION] Unhandled case (data_domain='#{data_domain}'): #{inspect(diagnostics)}"
        )

        :telemetry.execute(telemetry_event_unhandled(), %{})

      _ ->
        :telemetry.execute(telemetry_event_handled(), %{})
    end

    result
  end
end
