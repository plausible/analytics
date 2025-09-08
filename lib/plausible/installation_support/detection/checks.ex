defmodule Plausible.InstallationSupport.Detection.Checks do
  @moduledoc """
  Checks that are performed pre-installation, providing recommended installation
  methods and whether v1 is used on the site.

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

    CheckRunner.run(init_state, @checks,
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

  @unthrottled_checks 3
  @first_slowdown_ms 1000
  def run_with_rate_limit(url, data_domain, opts \\ []) do
    case Plausible.RateLimit.check_rate(
           "site_detection:#{data_domain}",
           :timer.minutes(60),
           10
         ) do
      {:allow, count} when count <= @unthrottled_checks ->
        {:ok, run(url, data_domain, opts)}

      {:allow, count} when count > @unthrottled_checks ->
        # slowdown steps 1x, 4x, 9x, 16x, ...
        slowdown_ms = @first_slowdown_ms * (count - @unthrottled_checks) ** 2
        :timer.sleep(slowdown_ms)
        {:ok, run(url, data_domain, opts)}

      {:deny, limit} ->
        {:error, {:rate_limit_exceeded, limit}}
    end
  end
end
