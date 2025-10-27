defmodule Plausible.InstallationSupport.Detection.ChecksTest do
  use PlausibleWeb.ConnCase, async: true

  @moduletag :ee_only

  on_ee do
    use Plausible.Test.Support.DNS
    import Plausible.AssertMatches
    alias Plausible.InstallationSupport.Detection.Checks
    alias Plausible.InstallationSupport.Result

    @moduletag :capture_log

    @expected_domain "example.com"

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
