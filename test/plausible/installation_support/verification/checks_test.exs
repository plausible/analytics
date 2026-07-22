defmodule Plausible.InstallationSupport.Verification.ChecksTest do
  use PlausibleWeb.ConnCase, async: true

  @moduletag :ee_only

  on_ee do
    use Plausible.Test.Support.DNS
    import Plausible.AssertMatches
    alias Plausible.InstallationSupport.Verification.{Checks, Diagnostics}
    alias Plausible.InstallationSupport.Result

    @moduletag :capture_log

    @expected_domain "example.com"
    @url_to_verify "https://#{@expected_domain}"
    @verify_manually_url "https://plausible.io/docs/troubleshoot-integration#how-to-manually-check-your-integration"
    @verify_manually_inline_link %{
      text: "verify your installation manually",
      href: @verify_manually_url
    }

    describe "URL check" do
      test "returns error when DNS check fails with domain not found error, offers custom URL input" do
        stub_lookup_a_records(@expected_domain, [])

        assert_matches %Result{
                         ok?: false,
                         data: %{offer_custom_url_input: true},
                         errors: [
                           ^any(:string, ~r/We couldn't reach #{@url_to_verify}$/)
                         ],
                         recommendations: [
                           %{
                             text:
                               "Check that the URL is correct and publicly accessible. If your site is intentionally private, you can verify your installation manually",
                             inline_links: [^@verify_manually_inline_link]
                           }
                         ]
                       } =
                         Checks.run(@url_to_verify, @expected_domain, "manual",
                           report_to: nil,
                           async?: false,
                           slowdown: 0
                         )
                         |> Checks.interpret_diagnostics()
      end

      test "returns error when DNS check fails with invalid URL error, offers custom URL input" do
        url_to_verify = "file://#{@expected_domain}"
        stub_lookup_a_records(@expected_domain, [])

        assert_matches %Result{
                         ok?: false,
                         data: %{offer_custom_url_input: true},
                         errors: [
                           ^any(:string, ~r/We couldn't reach #{url_to_verify}$/)
                         ],
                         recommendations: [
                           %{
                             text:
                               "Check that the URL is correct and publicly accessible. If your site is intentionally private, you can verify your installation manually",
                             inline_links: [^@verify_manually_inline_link]
                           }
                         ]
                       } =
                         Checks.run(url_to_verify, @expected_domain, "manual",
                           report_to: nil,
                           async?: false,
                           slowdown: 0
                         )
                         |> Checks.interpret_diagnostics()
      end
    end

    describe "VerifyInstallation check" do
      for status <- [200, 202] do
        test "returns success if test event response status is #{status} and domain is as expected" do
          verification_stub =
            json_response_verification_stub(%{
              "completed" => true,
              "trackerIsInHtml" => true,
              "plausibleIsOnWindow" => true,
              "plausibleIsInitialized" => true,
              "testEvent" => %{
                "normalizedBody" => %{
                  "domain" => @expected_domain
                },
                "responseStatus" => unquote(status)
              }
            })

          assert %Result{ok?: true} ==
                   run_checks(verification_stub, expected_req_count: 1)
                   |> Checks.interpret_diagnostics()
        end
      end

      for {installation_type, expected_recommendation} <- [
            {"wordpress",
             "Check you've installed the WordPress plugin correctly, or verify your installation manually"},
            {"gtm",
             "Check you've entered the ID in the GTM template correctly, or verify your installation manually"},
            {"npm",
             "Check you've initialized Plausible with the correct domain, or verify your installation manually"},
            {"manual",
             "Check that the snippet on your site matches the one shown in the installation instructions, or verify your installation manually"}
          ] do
        test "returns error when test event domain doesn't match the expected domain, with recommendation for installation type: #{installation_type}" do
          verification_stub =
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

          assert_matches %Result{
                           ok?: false,
                           errors: ["Your Plausible snippet is configured for a different domain"],
                           recommendations: [
                             %{
                               text: unquote(expected_recommendation),
                               inline_links: [^@verify_manually_inline_link]
                             }
                           ]
                         } =
                           run_checks(verification_stub,
                             installation_type: unquote(installation_type),
                             expected_req_count: 2
                           )
                           |> Checks.interpret_diagnostics()
        end
      end

      test "returns error when proxy network error occurs" do
        verification_stub =
          json_response_verification_stub(%{
            "completed" => true,
            "trackerIsInHtml" => true,
            "plausibleIsOnWindow" => true,
            "plausibleIsInitialized" => true,
            "testEvent" => %{
              "requestUrl" => "https://proxy.example.com/event",
              "normalizedBody" => %{
                "domain" => "example.com"
              },
              "responseStatus" => 500
            }
          })

        assert_matches %Result{
                         ok?: false,
                         errors: [^any(:string, ~r/.*proxied.*/)],
                         recommendations: [
                           %{
                             text: ^any(:string, ~r/.*proxied.*/),
                             inline_links: [
                               %{
                                 text: "Learn more",
                                 href: "https://plausible.io/docs/proxy/introduction"
                               }
                             ]
                           }
                         ]
                       } =
                         run_checks(verification_stub, expected_req_count: 2)
                         |> Checks.interpret_diagnostics()
      end

      test "returns error when Plausible network error occurs" do
        verification_stub =
          json_response_verification_stub(%{
            "completed" => true,
            "trackerIsInHtml" => true,
            "plausibleIsOnWindow" => true,
            "plausibleIsInitialized" => true,
            "testEvent" => %{
              "requestUrl" => PlausibleWeb.Endpoint.url() <> "/api/event",
              "normalizedBody" => %{
                "domain" => "example.com"
              },
              "responseStatus" => 500
            }
          })

        assert_matches %Result{
                         ok?: false,
                         errors: [^any(:string, ~r/.*couldn't verify.*/)],
                         recommendations: [
                           %{
                             text:
                               "Please try verifying again in a few minutes, or verify your installation manually",
                             inline_links: [^@verify_manually_inline_link]
                           }
                         ]
                       } =
                         run_checks(verification_stub, expected_req_count: 2)
                         |> Checks.interpret_diagnostics()
      end

      test "returns error when the snippet is not found for manual installation method, it has priority over CSP-related error" do
        verification_stub =
          json_response_verification_stub(%{
            "completed" => true,
            "trackerIsInHtml" => false,
            "plausibleIsOnWindow" => nil,
            "plausibleIsInitialized" => nil,
            "disallowedByCsp" => true
          })

        assert_matches %Result{
                         ok?: false,
                         errors: ["We couldn't detect Plausible on your site"],
                         recommendations: [
                           %{
                             text:
                               "Make sure you've copied the snippet to the head of your site, or verify your installation manually",
                             inline_links: [^@verify_manually_inline_link]
                           }
                         ]
                       } =
                         run_checks(verification_stub, expected_req_count: 2)
                         |> Checks.interpret_diagnostics()
      end

      test "returns error when Plausible domain is disallowed by CSP" do
        verification_stub =
          json_response_verification_stub(%{
            "completed" => true,
            "trackerIsInHtml" => true,
            "plausibleIsOnWindow" => nil,
            "plausibleIsInitialized" => nil,
            "disallowedByCsp" => true
          })

        assert_matches %Result{
                         ok?: false,
                         errors: [
                           "Your site's Content Security Policy (CSP) is blocking Plausible"
                         ],
                         recommendations: [
                           %{
                             text:
                               "Add plausible.io to the list of allowed domains in your site's Content Security Policy to allow Plausible to collect analytics. Learn more",
                             inline_links: [
                               %{
                                 text: "Learn more",
                                 href:
                                   "https://plausible.io/docs/troubleshoot-integration#does-your-site-use-a-content-security-policy-csp"
                               }
                             ]
                           }
                         ]
                       } =
                         run_checks(verification_stub, expected_req_count: 2)
                         |> Checks.interpret_diagnostics()
      end

      test "returns error when there's a network error during verification, offers custom URL input" do
        verification_stub =
          json_response_verification_stub(%{
            "completed" => false,
            "error" => %{"message" => "net::ERR_CONNECTION_CLOSED at #{@url_to_verify}"}
          })

        assert_matches %Result{
                         ok?: false,
                         data: %{offer_custom_url_input: true},
                         errors: ["We couldn't verify https://example.com"],
                         recommendations: [
                           %{
                             text:
                               "We encountered a network error while trying to access your website. You can verify your installation manually",
                             inline_links: [^@verify_manually_inline_link]
                           }
                         ]
                       } =
                         run_checks(verification_stub, expected_req_count: 2)
                         |> Checks.interpret_diagnostics()
      end

      test "returns error when Plausible not installed and website response status is not 200, offers custom URL input" do
        verification_stub =
          json_response_verification_stub(%{
            "completed" => true,
            "responseStatus" => 403,
            "trackerIsInHtml" => nil,
            "plausibleIsOnWindow" => nil,
            "plausibleIsInitialized" => nil,
            "testEvent" => %{"error" => "Timed out"}
          })

        assert_matches %Result{
                         ok?: false,
                         data: %{offer_custom_url_input: true},
                         errors: ["We couldn't verify https://example.com"],
                         recommendations: [
                           %{
                             text:
                               "Accessing your website returned an unexpected status code (403). Check for anything that might be blocking our access to your site, such as a firewall, authentication requirements, or CDN rules. You can also verify your installation manually",
                             inline_links: [^@verify_manually_inline_link]
                           }
                         ]
                       } =
                         run_checks(verification_stub, expected_req_count: 2)
                         |> Checks.interpret_diagnostics()
      end

      for {installation_type, expected_recommendation} <- [
            {"wordpress",
             "Make sure you've enabled the WordPress plugin, or verify your installation manually"},
            {"gtm",
             "Make sure you've configured the GTM template correctly, or verify your installation manually"},
            {"npm",
             "Make sure you've initialized Plausible on your site, or verify your installation manually"},
            {"manual",
             "Make sure you've copied the snippet to the head of your site, or verify your installation manually"}
          ] do
        test "returns error \"We couldn't detect Plausible on your site\" when plausible_is_on_window is false (with best guess recommendation for installation type: #{installation_type})" do
          verification_stub =
            json_response_verification_stub(%{
              "completed" => true,
              "responseStatus" => 200,
              "trackerIsInHtml" => false,
              "plausibleIsOnWindow" => false,
              "plausibleIsInitialized" => false,
              "testEvent" => %{"error" => "Timed out"}
            })

          assert_matches %Result{
                           ok?: false,
                           errors: ["We couldn't detect Plausible on your site"],
                           recommendations: [
                             %{
                               text: unquote(expected_recommendation),
                               inline_links: [^@verify_manually_inline_link]
                             }
                           ]
                         } =
                           run_checks(verification_stub,
                             installation_type: unquote(installation_type),
                             expected_req_count: 2
                           )
                           |> Checks.interpret_diagnostics()
        end

        test "falls back to error \"We couldn't detect Plausible on your site\" when no other case matches (with best guess recommendation for installation type: #{installation_type}), sends diagnostics to Sentry" do
          verification_stub =
            json_response_verification_stub(%{
              "completed" => true,
              "responseStatus" => nil,
              "trackerIsInHtml" => nil,
              "plausibleIsOnWindow" => nil,
              "plausibleIsInitialized" => nil,
              "testEvent" => nil
            })

          assert_matches %Result{
                           ok?: false,
                           errors: ["We couldn't detect Plausible on your site"],
                           recommendations: [
                             %{
                               text: unquote(expected_recommendation),
                               inline_links: [^@verify_manually_inline_link]
                             }
                           ]
                         } =
                           run_checks(verification_stub,
                             installation_type: unquote(installation_type),
                             expected_req_count: 1
                           )
                           |> Checks.interpret_diagnostics()
        end
      end
    end

    describe "VerifyInstallation & VerifyInstallationCacheBust" do
      test "returns error when it 'succeeds', but only after cache bust" do
        counter = :atomics.new(1, [])

        get_context_url_from_body = fn conn ->
          {:ok, body, _conn} = Plug.Conn.read_body(conn)
          JSON.decode!(body)["context"]["url"]
        end

        verification_stub = fn conn ->
          js_data =
            if :atomics.add_get(counter, 1, 1) == 1 do
              assert get_context_url_from_body.(conn) == @url_to_verify

              %{
                "completed" => true,
                "trackerIsInHtml" => false,
                "plausibleIsOnWindow" => false,
                "plausibleIsInitialized" => false
              }
            else
              assert [_, "plausible_verification" <> _] =
                       String.split(get_context_url_from_body.(conn), "?")

              %{
                "completed" => true,
                "trackerIsInHtml" => true,
                "plausibleIsOnWindow" => true,
                "plausibleIsInitialized" => true,
                "testEvent" => %{
                  "normalizedBody" => %{
                    "domain" => "example.com"
                  },
                  "responseStatus" => 200
                }
              }
            end

          conn
          |> put_resp_content_type("application/json")
          |> send_resp(200, Jason.encode!(%{"data" => js_data}))
        end

        assert_matches %Result{
                         ok?: false,
                         errors: [^any(:string, ~r/.*cache.*/)],
                         recommendations: [
                           %{
                             text: ^any(:string, ~r/.*cache.*/),
                             inline_links: [
                               %{
                                 text: "Learn more",
                                 href:
                                   "https://plausible.io/docs/troubleshoot-integration#have-you-cleared-the-cache-of-your-site"
                               }
                             ]
                           }
                         ]
                       } = run_checks(verification_stub) |> Checks.interpret_diagnostics()

        assert 2 == :atomics.get(counter, 1)
      end

      test "cache bust diagnostics fully replace the initial installation check diagnostics" do
        counter = :atomics.new(1, [])

        verification_stub = fn conn ->
          if :atomics.add_get(counter, 1, 1) == 1 do
            js_data =
              %{
                "completed" => true,
                "trackerIsInHtml" => false,
                "plausibleIsOnWindow" => false,
                "plausibleIsInitialized" => false
              }

            conn
            |> put_resp_content_type("application/json")
            |> send_resp(200, Jason.encode!(%{"data" => js_data}))
          else
            Req.Test.transport_error(conn, :timeout)
          end
        end

        state = run_checks(verification_stub)

        assert_matches %Diagnostics{
                         tracker_is_in_html: nil,
                         plausible_is_on_window: nil,
                         plausible_is_initialized: nil,
                         service_error: %{code: :browserless_timeout}
                       } = state.diagnostics

        # Browserless gets called 3 times:
        #   1) initial/regular installation check
        #   2) cache bust installation check
        #   3) retry due to #2 timing out
        assert 3 == :atomics.get(counter, 1)
      end

      test "timeouts are retried, cache bust skipped, interpreted as temporary errors" do
        verification_stub = fn conn ->
          Req.Test.transport_error(conn, :timeout)
        end

        state = run_checks(verification_stub, expected_req_count: 2)

        assert_matches %Diagnostics{service_error: %{code: :browserless_timeout}} =
                         state.diagnostics

        assert_matches %Result{
                         ok?: false,
                         errors: [^any(:string, ~r/.*temporarily unavailable.*/)],
                         recommendations: [
                           %{
                             text:
                               "Please try again in a few minutes or verify your installation manually",
                             inline_links: [^@verify_manually_inline_link]
                           }
                         ]
                       } = Checks.interpret_diagnostics(state)
      end

      for status <- [400, 429] do
        test "#{status} responses are retried, cache bust skipped, interpreted as temporary errors" do
          verification_stub = fn conn ->
            conn
            |> put_resp_content_type("text/html")
            |> send_resp(unquote(status), "some error message")
          end

          state = run_checks(verification_stub, expected_req_count: 2)

          assert_matches %Diagnostics{
                           service_error: %{
                             code: :bad_browserless_response,
                             extra: ^unquote(status)
                           }
                         } = state.diagnostics

          assert_matches %Result{
                           ok?: false,
                           errors: [^any(:string, ~r/.*temporarily unavailable.*/)],
                           recommendations: [
                             %{
                               text:
                                 "Please try again in a few minutes or verify your installation manually",
                               inline_links: [^@verify_manually_inline_link]
                             }
                           ]
                         } = Checks.interpret_diagnostics(state)
        end
      end
    end

    defp json_response_verification_stub(js_data) do
      fn conn ->
        conn
        |> put_resp_content_type("application/json")
        |> send_resp(200, Jason.encode!(%{"data" => js_data}))
      end
    end

    defp run_checks(verification_stub, opts \\ []) do
      installation_type = Keyword.get(opts, :installation_type, "manual")
      expected_req_count = Keyword.get(opts, :expected_req_count)

      stub_lookup_a_records(@expected_domain)

      if is_integer(expected_req_count) do
        counter = :atomics.new(1, [])

        stub_verification_result(fn conn ->
          :atomics.add_get(counter, 1, 1)
          verification_stub.(conn)
        end)

        state =
          Checks.run(@url_to_verify, @expected_domain, installation_type,
            report_to: nil,
            async?: false,
            slowdown: 0
          )

        assert expected_req_count == :atomics.get(counter, 1)

        state
      else
        stub_verification_result(verification_stub)

        Checks.run(@url_to_verify, @expected_domain, installation_type,
          report_to: nil,
          async?: false,
          slowdown: 0
        )
      end
    end

    defp stub_verification_result(f) do
      Req.Test.stub(Plausible.InstallationSupport.Checks.VerifyInstallation, f)
    end
  end
end
