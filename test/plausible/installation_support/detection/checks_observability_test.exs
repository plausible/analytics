defmodule Plausible.InstallationSupport.Detection.ChecksObservabilityTest do
  @moduledoc """
  Tests for capturing logs/telemetry/Sentry upon detection diagnostics interpretation.
  Needs to be synchronous due to Sentry assertions, hence a separate module.
  """
  use PlausibleWeb.ConnCase, async: false

  @moduletag :ee_only

  on_ee do
    use Plausible.Test.Support.DNS
    import ExUnit.CaptureLog
    alias Plausible.InstallationSupport.Detection.Checks

    @moduletag :capture_log

    @expected_domain "example.com"
    @working_url "https://#{@expected_domain}"

    setup %{test: test, test_pid: test_pid} do
      :telemetry.attach_many(
        "#{test}-telemetry-handler",
        [
          Checks.telemetry_event_success(),
          Checks.telemetry_event_failure()
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

    test "successful detection -> no logs, no sentry, telemetry :success" do
      stub_lookup_a_records(@expected_domain)

      detection_stub =
        json_response_detection_stub(%{
          "completed" => true,
          "v1Detected" => nil,
          "gtmLikely" => false,
          "npm" => false,
          "wordpressLikely" => true,
          "wordpressPlugin" => false
        })

      state = run_checks(detection_stub)

      log = capture_log(fn -> Checks.interpret_diagnostics(state) end)

      assert log == ""

      assert [] = Sentry.Test.pop_sentry_reports()

      assert_receive {:telemetry_event, telemetry_event}
      assert telemetry_event == Checks.telemetry_event_success()
    end

    test "domain not found -> customer website issue" do
      stub_lookup_a_records(@expected_domain, [])

      detection_counter =
        Req.Test.stub(Plausible.InstallationSupport.Checks.Detection, fn _conn ->
          raise "This check should've been skipped"
        end)

      state =
        Checks.run(@working_url, @expected_domain,
          report_to: nil,
          async?: false,
          slowdown: 0
        )

      log = capture_log(fn -> Checks.interpret_diagnostics(state) end)

      assert detection_counter

      assert log =~ "[DETECTION] Failed due to an issue with the customer website"
      assert log =~ "service_error: %{code: :domain_not_found}"

      assert [] = Sentry.Test.pop_sentry_reports()

      assert_receive {:telemetry_event, telemetry_event}
      assert telemetry_event == Checks.telemetry_event_failure()
    end

    for msg <- ["Execution context destroyed", "net::ERR_CONNECTION_REFUSED"] do
      test "failure due to a known :browserless_client_error (#{msg}) -> customer website issue" do
        stub_lookup_a_records(@expected_domain)

        detection_stub =
          json_response_detection_stub(%{
            "completed" => false,
            "error" => %{"message" => unquote(msg)}
          })

        state = run_checks(detection_stub)

        log = capture_log(fn -> Checks.interpret_diagnostics(state) end)

        assert log =~ "[DETECTION] Failed due to an issue with the customer website"
        assert log =~ "code: :browserless_client_error"
        assert log =~ ~s|extra: "#{unquote(msg)}"|

        assert [] = Sentry.Test.pop_sentry_reports()

        assert_receive {:telemetry_event, telemetry_event}
        assert telemetry_event == Checks.telemetry_event_failure()
      end
    end

    test "failure due to an unknown :browserless_client_error -> unknown failure" do
      stub_lookup_a_records(@expected_domain)

      detection_stub =
        json_response_detection_stub(%{
          "completed" => false,
          "error" => %{"message" => "something unexpected"}
        })

      state = run_checks(detection_stub)

      log = capture_log(fn -> Checks.interpret_diagnostics(state) end)

      assert log =~ "[DETECTION] Unknown failure"
      assert log =~ "code: :browserless_client_error"
      assert log =~ ~s|extra: "something unexpected"|

      assert [sentry_event] = Sentry.Test.pop_sentry_reports()
      assert sentry_event.message.formatted == "[DETECTION] Unknown failure"

      assert_receive {:telemetry_event, telemetry_event}
      assert telemetry_event == Checks.telemetry_event_failure()
    end

    test "failure hitting the catch-all interpret clause -> unknown failure" do
      stub_lookup_a_records(@expected_domain)

      detection_stub = fn conn ->
        Req.Test.transport_error(conn, :econnrefused)
      end

      state = run_checks(detection_stub)

      log = capture_log(fn -> Checks.interpret_diagnostics(state) end)

      assert log =~ "[DETECTION] Unknown failure"
      assert log =~ "code: :req_error"
      assert log =~ ~s|extra: :econnrefused|

      assert [sentry_event] = Sentry.Test.pop_sentry_reports()
      assert sentry_event.message.formatted == "[DETECTION] Unknown failure"

      assert_receive {:telemetry_event, telemetry_event}
      assert telemetry_event == Checks.telemetry_event_failure()
    end

    test "failure due to a flaky browserless issue -> browserless issue" do
      stub_lookup_a_records(@expected_domain)

      detection_stub = fn conn ->
        conn
        |> put_resp_content_type("text/html")
        |> send_resp(400, "some error message")
      end

      state = run_checks(detection_stub)

      log = capture_log(fn -> Checks.interpret_diagnostics(state) end)

      assert log =~ "[DETECTION] Failed due to a Browserless issue"
      assert log =~ "code: :bad_browserless_response"
      assert log =~ "extra: 400"

      assert [sentry_event] = Sentry.Test.pop_sentry_reports()
      assert sentry_event.message.formatted == "[DETECTION] Failed due to a Browserless issue"

      assert_receive {:telemetry_event, telemetry_event}
      assert telemetry_event == Checks.telemetry_event_failure()
    end

    test "failure due to a browserless timeout -> browserless issue" do
      stub_lookup_a_records(@expected_domain)

      detection_stub = fn conn ->
        Req.Test.transport_error(conn, :timeout)
      end

      state = run_checks(detection_stub)

      log = capture_log(fn -> Checks.interpret_diagnostics(state) end)

      assert log =~ "[DETECTION] Failed due to a Browserless issue"
      assert log =~ "code: :browserless_timeout"

      assert [sentry_event] = Sentry.Test.pop_sentry_reports()
      assert sentry_event.message.formatted == "[DETECTION] Failed due to a Browserless issue"

      assert_receive {:telemetry_event, telemetry_event}
      assert telemetry_event == Checks.telemetry_event_failure()
    end

    test "failure due to internal_check_timeout -> browserless issue" do
      stub_lookup_a_records(@expected_domain)

      detection_stub = fn _conn ->
        # times out
        Process.sleep(1000)
      end

      Req.Test.stub(Plausible.InstallationSupport.Checks.Detection, detection_stub)

      state =
        Checks.run(@working_url, @expected_domain,
          detection_check_timeout: 100,
          report_to: nil,
          async?: false,
          slowdown: 0
        )

      log = capture_log(fn -> Checks.interpret_diagnostics(state) end)

      assert log =~ "[DETECTION] Failed due to a Browserless issue"
      assert log =~ "code: :internal_check_timeout"

      assert [sentry_event] = Sentry.Test.pop_sentry_reports()
      assert sentry_event.message.formatted == "[DETECTION] Failed due to a Browserless issue"

      assert_receive {:telemetry_event, telemetry_event}
      assert telemetry_event == Checks.telemetry_event_failure()
    end

    defp json_response_detection_stub(js_data) do
      fn conn ->
        conn
        |> put_resp_content_type("application/json")
        |> send_resp(200, Jason.encode!(%{"data" => js_data}))
      end
    end

    defp run_checks(detection_stub) do
      Req.Test.stub(Plausible.InstallationSupport.Checks.Detection, detection_stub)

      Checks.run(@working_url, @expected_domain,
        report_to: nil,
        async?: false,
        slowdown: 0
      )
    end
  end
end
