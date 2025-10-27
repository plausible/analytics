defmodule Plausible.InstallationSupport.Verification.ChecksObservabilityTest do
  @moduledoc """
  Tests for capturing logs/telemetry/Sentry upon verification diagnostics interpretation.
  Needs to be synchronous due to Sentry assertions, hence a separate module.
  """

  use PlausibleWeb.ConnCase, async: false

  @moduletag :ee_only

  on_ee do
    use Plausible.Test.Support.DNS
    import ExUnit.CaptureLog
    alias Plausible.InstallationSupport.Verification.{Checks}

    @moduletag :capture_log

    @expected_domain "example.com"
    @url_to_verify "https://#{@expected_domain}"

    setup %{test: test, test_pid: test_pid} do
      :telemetry.attach_many(
        "#{test}-telemetry-handler",
        [
          Checks.telemetry_event_handled(),
          Checks.telemetry_event_unhandled()
        ],
        fn event, %{}, _, _ ->
          send(test_pid, {:telemetry_event, event})
        end,
        %{}
      )

      Sentry.put_config(:test_mode, true)
      Sentry.put_config(:send_result, :sync)
      Sentry.put_config(:dedup_events, false)

      assert :ok = Sentry.Test.start_collecting(owner: test_pid)

      on_exit(fn ->
        Sentry.put_config(:test_mode, false)
        Sentry.put_config(:send_result, :none)
        Sentry.put_config(:dedup_events, true)
      end)
    end

    test "known installation issue detected is considered handled" do
      wrong_domain_verification_stub =
        json_response_verification_stub(%{
          "completed" => true,
          "trackerIsInHtml" => true,
          "plausibleIsOnWindow" => true,
          "plausibleIsInitialized" => true,
          "testEvent" => %{
            "normalizedBody" => %{
              "domain" => "wrong-domain.com"
            },
            "responseStatus" => 200
          }
        })

      state = run_checks(wrong_domain_verification_stub)

      log = capture_log(fn -> Checks.interpret_diagnostics(state) end)

      assert log == ""

      assert_receive {:telemetry_event, telemetry_event}
      assert telemetry_event == Checks.telemetry_event_handled()

      assert [] = Sentry.Test.pop_sentry_reports()
    end

    test "unhandled verification case" do
      verification_stub =
        json_response_verification_stub(%{
          "completed" => true,
          "trackerIsInHtml" => true,
          "plausibleIsOnWindow" => true,
          "plausibleIsInitialized" => true,
          "testEvent" => %{}
        })

      state = run_checks(verification_stub)

      log = capture_log(fn -> Checks.interpret_diagnostics(state) end)

      assert log =~ "[VERIFICATION] Unhandled case (data_domain='#{@expected_domain}')"
      assert log =~ "test_event: %{}"

      assert_receive {:telemetry_event, telemetry_event}
      assert telemetry_event == Checks.telemetry_event_unhandled()

      assert [sentry_event] = Sentry.Test.pop_sentry_reports()
      assert sentry_event.message.formatted == "Unhandled case for site verification"
    end

    test "browserless request timing out is considered unhandled" do
      verification_stub = fn conn -> Req.Test.transport_error(conn, :timeout) end
      state = run_checks(verification_stub)

      log = capture_log(fn -> Checks.interpret_diagnostics(state) end)

      assert log =~ "[VERIFICATION] Unhandled case (data_domain='#{@expected_domain}')"
      assert log =~ "service_error: %{code: :browserless_timeout}"

      assert_receive {:telemetry_event, telemetry_event}
      assert telemetry_event == Checks.telemetry_event_unhandled()

      assert [sentry_event] = Sentry.Test.pop_sentry_reports()
      assert sentry_event.message.formatted == "Browserless failure in verification"
    end

    test "flaky Browserless response is considered unhandled" do
      verification_stub = fn conn ->
        conn
        |> put_resp_content_type("text/html")
        |> send_resp(400, "some error message")
      end

      state = run_checks(verification_stub)

      log = capture_log(fn -> Checks.interpret_diagnostics(state) end)

      assert log =~ "[VERIFICATION] Unhandled case (data_domain='#{@expected_domain}')"
      assert log =~ "service_error: %{code: :bad_browserless_response, extra: 400}"

      assert_receive {:telemetry_event, telemetry_event}
      assert telemetry_event == Checks.telemetry_event_unhandled()

      assert [sentry_event] = Sentry.Test.pop_sentry_reports()
      assert sentry_event.message.formatted == "Browserless failure in verification"
    end

    test "internal_check_timeout is considered unhandled" do
      verification_stub = fn _conn ->
        # times out
        Process.sleep(1000)
      end

      stub_lookup_a_records(@expected_domain)
      stub_verification_result(verification_stub)

      state =
        Checks.run(@url_to_verify, @expected_domain, "manual",
          verify_installation_check_timeout: 100,
          report_to: nil,
          async?: false,
          slowdown: 0
        )

      log = capture_log(fn -> Checks.interpret_diagnostics(state) end)

      assert log =~ "[VERIFICATION] Unhandled case (data_domain='#{@expected_domain}')"
      assert log =~ "code: :internal_check_timeout"
      assert log =~ ~s|extra: "VerifyInstallation timed out after 100ms"|

      assert_receive {:telemetry_event, telemetry_event}
      assert telemetry_event == Checks.telemetry_event_unhandled()

      assert [sentry_event] = Sentry.Test.pop_sentry_reports()
      assert sentry_event.message.formatted == "Browserless failure in verification"
    end

    defp json_response_verification_stub(js_data) do
      fn conn ->
        conn
        |> put_resp_content_type("application/json")
        |> send_resp(200, Jason.encode!(%{"data" => js_data}))
      end
    end

    defp run_checks(verification_stub) do
      stub_lookup_a_records(@expected_domain)
      stub_verification_result(verification_stub)

      Checks.run(@url_to_verify, @expected_domain, "manual",
        report_to: nil,
        async?: false,
        slowdown: 0
      )
    end

    defp stub_verification_result(f) do
      Req.Test.stub(Plausible.InstallationSupport.Checks.VerifyInstallation, f)
    end
  end
end
