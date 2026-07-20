defmodule Plausible.InstallationSupport.Verification.Checks do
  @moduledoc """
  Checks that are performed during tracker script installation verification.

  In async execution, each check notifies the caller by sending a message to it.
  """
  alias Plausible.InstallationSupport.Verification
  alias Plausible.InstallationSupport.{State, CheckRunner, Checks}

  require Logger

  @verify_installation_check_timeout 20_000

  # Local UI debugging only - set to one of the keys below to make every
  # verification run return that canned interpretation, regardless of what
  # the real check pipeline actually found. Handy for iterating on
  # PlausibleWeb.Live.Verification's banner UI states. Must be `nil` on commit.
  @debug_scenario nil

  @debug_scenarios %{
    0 => :success,
    1 => %Verification.Diagnostics{},
    2 => %Verification.Diagnostics{selected_installation_type: "wordpress"},
    3 => %Verification.Diagnostics{
      plausible_is_on_window: false,
      plausible_is_initialized: false,
      service_error: %{code: :domain_not_found}
    },
    4 => %Verification.Diagnostics{disallowed_by_csp: true}
  }

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
    {diagnostics, url} = debug_override(diagnostics, data_domain, url)

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

  # Also overrides `url` to a clean, query-string-free one - otherwise the
  # real check pipeline's cache-busting query param (?plausible_verification=...)
  # leaks into canned error messages like "We couldn't find your website at ...".
  defp debug_override(diagnostics, data_domain, url) do
    case Map.get(@debug_scenarios, @debug_scenario) do
      nil ->
        {diagnostics, url}

      :success ->
        {
          %Verification.Diagnostics{
            test_event: %{
              "normalizedBody" => %{"domain" => data_domain},
              "responseStatus" => 200
            }
          },
          "https://#{data_domain}"
        }

      %Verification.Diagnostics{} = debug ->
        {debug, "https://#{data_domain}"}
    end
  end
end
