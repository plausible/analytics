defmodule Plausible.InstallationSupport.Detection.ChecksTest do
  use Plausible
  use Plausible.DataCase, async: true

  @moduletag :ee_only

  on_ee do
    import Plausible.AssertMatches
    alias Plausible.InstallationSupport.Detection.{Checks}
    alias Plausible.InstallationSupport.Result
    use Plausible.Test.Support.DNS
    import Plug.Conn
    import ExUnit.CaptureLog
    @moduletag :capture_log

    @expected_domain "example.com"
    @working_url "https://#{@expected_domain}"

    describe "running detection" do
      test "handles wordpress detection, retrying on 429" do
        url_to_verify = nil
        test = self()
        stub_lookup_a_records(@expected_domain)

        get_context_from_body = fn conn ->
          {:ok, body, _conn} = Plug.Conn.read_body(conn)
          JSON.decode!(body)["context"]
        end

        detection_counter =
          stub_detection_result_with_counter(fn conn, request_i ->
            send(test, get_context_from_body.(conn))

            case request_i do
              1 ->
                conn |> send_resp(429, "Too Many Requests")

              _ ->
                conn
                |> put_resp_content_type("application/json")
                |> send_resp(
                  200,
                  JSON.encode!(%{
                    "data" => %{
                      "completed" => true,
                      "v1Detected" => nil,
                      "gtmLikely" => false,
                      "npm" => false,
                      "wordpressLikely" => true,
                      "wordpressPlugin" => false
                    }
                  })
                )
            end
          end)

        assert %Result{
                 ok?: true,
                 data: %{
                   v1_detected: nil,
                   wordpress_plugin: false,
                   npm: false,
                   suggested_technology: "wordpress"
                 }
               } ==
                 Checks.run(url_to_verify, @expected_domain,
                   report_to: nil,
                   async?: false,
                   slowdown: 0
                 )
                 |> Checks.interpret_diagnostics()

        assert_receive context

        assert_matches ^strict_map(%{
                         "debug" => false,
                         "detectV1" => false,
                         "timeoutMs" => 1500,
                         "url" =>
                           ^any(
                             :string,
                             ~r/https:\/\/#{@expected_domain}\?plausible_verification=\d+$/
                           ),
                         "userAgent" =>
                           "Plausible Verification Agent - if abused, contact support@plausible.io"
                       }) = context

        assert 2 == :atomics.get(detection_counter, 1)
      end
    end

    describe "observability" do
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
      end

      test "successful detection -> no logs, telemetry :success" do
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

        assert_receive {:telemetry_event, telemetry_event}
        assert telemetry_event == Checks.telemetry_event_failure()
      end
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

    defp stub_detection_result_with_counter(handler) do
      counter = :atomics.new(1, [])

      Req.Test.stub(Plausible.InstallationSupport.Checks.Detection, fn conn ->
        request_i = :atomics.add_get(counter, 1, 1)

        handler.(conn, request_i)
      end)

      counter
    end
  end
end
