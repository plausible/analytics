defmodule Plausible.InstallationSupport.Detection.Checks do
  @moduledoc """
  Checks that are performed pre-installation, providing recommended installation
  methods and whether v1 is used on the site.

  In async execution, each check notifies the caller by sending a message to it.
  """
  alias Plausible.InstallationSupport.Detection
  alias Plausible.InstallationSupport.{State, CheckRunner, Checks}

  require Logger

  @detection_check_timeout 6000

  def run(url, data_domain, opts \\ []) do
    detection_check_timeout =
      case Keyword.get(opts, :detection_check_timeout) do
        int when is_integer(int) -> int
        _ -> @detection_check_timeout
      end

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

    checks = [
      {Checks.Url, []},
      {Checks.Detection, [timeout: detection_check_timeout]}
    ]

    CheckRunner.run(init_state, checks,
      async?: async?,
      report_to: report_to,
      slowdown: slowdown
    )
  end

  def telemetry_event_success(), do: [:plausible, :detection, :success]
  def telemetry_event_failure(), do: [:plausible, :detection, :failure]

  def interpret_diagnostics(%State{
        diagnostics: diagnostics,
        data_domain: data_domain,
        url: url
      }) do
    result = Detection.Diagnostics.interpret(diagnostics, url)

    {failed?, trigger_sentry?, msg} =
      case result do
        %{ok?: true} ->
          {false, false, nil}

        %{data: %{failure: :customer_website_issue}} ->
          {true, false, "Failed due to an issue with the customer website"}

        %{data: %{failure: :browserless_issue}} ->
          {true, true, "Failed due to a Browserless issue"}

        _unknown_failure ->
          {true, true, "Unknown failure"}
      end

    if failed? do
      :telemetry.execute(telemetry_event_failure(), %{})
      Logger.warning("[DETECTION] #{msg} (data_domain='#{data_domain}'): #{inspect(diagnostics)}")
    else
      :telemetry.execute(telemetry_event_success(), %{})
    end

    if trigger_sentry? do
      Sentry.capture_message("[DETECTION] #{msg}",
        extra: %{
          message: inspect(diagnostics),
          url: url,
          hash: :erlang.phash2(diagnostics)
        }
      )
    end

    result
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
