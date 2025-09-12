defmodule Plausible.InstallationSupport.Verification.ChecksTest do
  use Plausible
  use Plausible.DataCase, async: true

  @moduletag :ee_only

  on_ee do
    import Plausible.AssertMatches
    alias Plausible.InstallationSupport.Verification.Checks
    alias Plausible.InstallationSupport.Result
    use Plausible.Test.Support.DNS
    import Plug.Conn
    @moduletag :capture_log

    describe "running verification" do
      for status <- [200, 202] do
        test "returns success if test event response status is #{status} and domain is as expected" do
          expected_domain = "example.com"
          url_to_verify = "https://#{expected_domain}"

          stub_lookup_a_records(expected_domain)

          verification_counter =
            stub_verification_result(%{
              "completed" => true,
              "trackerIsInHtml" => true,
              "plausibleIsOnWindow" => true,
              "plausibleIsInitialized" => true,
              "testEvent" => %{
                "normalizedBody" => %{
                  "domain" => "example.com"
                },
                "responseStatus" => unquote(status)
              }
            })

          assert %Result{
                   ok?: true
                 } ==
                   Checks.run(url_to_verify, expected_domain, "manual",
                     report_to: nil,
                     async?: false,
                     slowdown: 0
                   )
                   |> Checks.interpret_diagnostics()

          assert 1 == :atomics.get(verification_counter, 1)
        end
      end

      test "returns error when it 'succeeds', but only after cache bust" do
        expected_domain = "example.com"
        url_to_verify = "https://#{expected_domain}"

        stub_lookup_a_records(expected_domain)

        verification_counter =
          stub_verification_result_i(fn i ->
            case i do
              1 ->
                %{
                  "completed" => true,
                  "trackerIsInHtml" => false,
                  "plausibleIsOnWindow" => false,
                  "plausibleIsInitialized" => false
                }

              2 ->
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
          end)

        assert_matches %Result{
                         ok?: false,
                         errors: [^any(:string, ~r/.*cache.*/)],
                         recommendations: [
                           %{
                             text: ^any(:string, ~r/.*cache.*/),
                             url:
                               "https://plausible.io/docs/troubleshoot-integration#have-you-cleared-the-cache-of-your-site"
                           }
                         ]
                       } =
                         Checks.run(url_to_verify, expected_domain, "manual",
                           report_to: nil,
                           async?: false,
                           slowdown: 0
                         )
                         |> Checks.interpret_diagnostics()

        assert 2 == :atomics.get(verification_counter, 1)
      end

      for {installation_type, expected_recommendation} <- [
            {"wordpress",
             "Please check that you've installed the WordPress plugin correctly, or verify your installation manually"},
            {"gtm",
             "Please check that you've entered the ID in the GTM template correctly, or verify your installation manually"},
            {"npm",
             "Please check that you've initialized Plausible with the correct domain, or verify your installation manually"},
            {"manual",
             "Please check that the snippet on your site matches the installation instructions exactly, or verify your installation manually"}
          ] do
        test "returns error when test event domain doesn't match the expected domain, with recommendation for installation type: #{installation_type}" do
          expected_domain = "example.com"
          url_to_verify = "https://#{expected_domain}"
          stub_lookup_a_records(expected_domain)

          verification_counter =
            stub_verification_result(%{
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
                           errors: ["Plausible test event is not for this site"],
                           recommendations: [
                             %{
                               text: unquote(expected_recommendation),
                               url:
                                 "https://plausible.io/docs/troubleshoot-integration#how-to-manually-check-your-integration"
                             }
                           ]
                         } =
                           Checks.run(url_to_verify, expected_domain, unquote(installation_type),
                             report_to: nil,
                             async?: false,
                             slowdown: 0
                           )
                           |> Checks.interpret_diagnostics()

          assert 2 == :atomics.get(verification_counter, 1)
        end
      end

      test "returns error when proxy network error occurs" do
        expected_domain = "example.com"
        url_to_verify = "https://#{expected_domain}"
        stub_lookup_a_records(expected_domain)

        verification_counter =
          stub_verification_result(%{
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
                         errors: [^any(:string, ~r/.*proxy.*/)],
                         recommendations: [
                           %{
                             text: ^any(:string, ~r/.*proxied.*/),
                             url: "https://plausible.io/docs/proxy/introduction"
                           }
                         ]
                       } =
                         Checks.run(url_to_verify, expected_domain, "manual",
                           report_to: nil,
                           async?: false,
                           slowdown: 0
                         )
                         |> Checks.interpret_diagnostics()

        assert 2 == :atomics.get(verification_counter, 1)
      end

      test "returns error when Plausible network error occurs" do
        expected_domain = "example.com"
        url_to_verify = "https://#{expected_domain}"
        stub_lookup_a_records(expected_domain)

        verification_counter =
          stub_verification_result(%{
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
                             text: ^any(:string, ~r/.*try verifying again.*/),
                             url:
                               "https://plausible.io/docs/troubleshoot-integration#how-to-manually-check-your-integration"
                           }
                         ]
                       } =
                         Checks.run(url_to_verify, expected_domain, "manual",
                           report_to: nil,
                           async?: false,
                           slowdown: 0
                         )
                         |> Checks.interpret_diagnostics()

        assert 2 == :atomics.get(verification_counter, 1)
      end

      test "returns error when the snippet is not found for manual installation method, it has priority over CSP-related error" do
        expected_domain = "example.com"
        url_to_verify = "https://#{expected_domain}"
        stub_lookup_a_records(expected_domain)

        verification_counter =
          stub_verification_result(%{
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
                               "Please make sure you've copied the snippet to the head of your site, or verify your installation manually",
                             url:
                               "https://plausible.io/docs/troubleshoot-integration#how-to-manually-check-your-integration"
                           }
                         ]
                       } =
                         Checks.run(url_to_verify, expected_domain, "manual",
                           report_to: nil,
                           async?: false,
                           slowdown: 0
                         )
                         |> Checks.interpret_diagnostics()

        assert 2 == :atomics.get(verification_counter, 1)
      end

      test "returns error when Plausible domain is disallowed by CSP" do
        expected_domain = "example.com"
        url_to_verify = "https://#{expected_domain}"
        stub_lookup_a_records(expected_domain)

        verification_counter =
          stub_verification_result(%{
            "completed" => true,
            "trackerIsInHtml" => true,
            "plausibleIsOnWindow" => nil,
            "plausibleIsInitialized" => nil,
            "disallowedByCsp" => true
          })

        assert_matches %Result{
                         ok?: false,
                         errors: [
                           "We encountered an issue with your site's Content Security Policy (CSP)"
                         ],
                         recommendations: [
                           %{
                             text:
                               "Please add plausible.io domain specifically to the allowed list of domains in your site's CSP",
                             url:
                               "https://plausible.io/docs/troubleshoot-integration#does-your-site-use-a-content-security-policy-csp"
                           }
                         ]
                       } =
                         Checks.run(url_to_verify, expected_domain, "manual",
                           report_to: nil,
                           async?: false,
                           slowdown: 0
                         )
                         |> Checks.interpret_diagnostics()

        assert 2 == :atomics.get(verification_counter, 1)
      end

      test "returns error when DNS check fails with domain not found error, offers custom URL input" do
        expected_domain = "example.com"
        url_to_verify = "https://#{expected_domain}"
        stub_lookup_a_records(expected_domain, [])

        assert_matches %Result{
                         ok?: false,
                         data: %{offer_custom_url_input: true},
                         errors: [
                           ^any(:string, ~r/We couldn't find your website at #{url_to_verify}$/)
                         ],
                         recommendations: [
                           %{
                             text:
                               "Please check that the domain you entered is correct and reachable publicly. If it's intentionally private, you'll need to verify that Plausible works manually",
                             url:
                               "https://plausible.io/docs/troubleshoot-integration#how-to-manually-check-your-integration"
                           }
                         ]
                       } =
                         Checks.run(url_to_verify, expected_domain, "manual",
                           report_to: nil,
                           async?: false,
                           slowdown: 0
                         )
                         |> Checks.interpret_diagnostics()
      end

      test "returns error when DNS check fails with invalid URL error, offers custom URL input" do
        expected_domain = "example.com"
        url_to_verify = "file://#{expected_domain}"
        stub_lookup_a_records(expected_domain, [])

        assert_matches %Result{
                         ok?: false,
                         data: %{offer_custom_url_input: true},
                         errors: [
                           ^any(:string, ~r/We couldn't find your website at #{url_to_verify}$/)
                         ],
                         recommendations: [
                           %{
                             text:
                               "Please check that the domain you entered is correct and reachable publicly. If it's intentionally private, you'll need to verify that Plausible works manually",
                             url:
                               "https://plausible.io/docs/troubleshoot-integration#how-to-manually-check-your-integration"
                           }
                         ]
                       } =
                         Checks.run(url_to_verify, expected_domain, "manual",
                           report_to: nil,
                           async?: false,
                           slowdown: 0
                         )
                         |> Checks.interpret_diagnostics()
      end

      test "returns error when there's a network error during verification, offers custom URL input" do
        expected_domain = "example.com"
        url_to_verify = "https://example.com?plausible_verification=123123123"
        stub_lookup_a_records(expected_domain)

        verification_counter =
          stub_verification_result(%{
            "completed" => false,
            "error" => %{"message" => "net::ERR_CONNECTION_CLOSED at #{url_to_verify}"}
          })

        assert_matches %Result{
                         ok?: false,
                         data: %{offer_custom_url_input: true},
                         errors: [
                           "We couldn't verify your website at https://example.com"
                         ],
                         recommendations: [
                           %{
                             text:
                               "Accessing the website resulted in a network error. Please verify your installation manually",
                             url:
                               "https://plausible.io/docs/troubleshoot-integration#how-to-manually-check-your-integration"
                           }
                         ]
                       } =
                         Checks.run(url_to_verify, expected_domain, "manual",
                           report_to: nil,
                           async?: false,
                           slowdown: 0
                         )
                         |> Checks.interpret_diagnostics()

        assert 2 == :atomics.get(verification_counter, 1)
      end

      test "returns error when Plausible not installed and website response status is not 200, offers custom URL input" do
        expected_domain = "example.com"
        url_to_verify = "https://#{expected_domain}?plausible_verification=123123123"
        stub_lookup_a_records(expected_domain)

        verification_counter =
          stub_verification_result(%{
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
                         errors: [
                           "We couldn't verify your website at https://example.com"
                         ],
                         recommendations: [
                           %{
                             text:
                               "Accessing the website resulted in an unexpected status code 403. Please check for anything that might be blocking us from reaching your site, like a firewall, authentication requirements, or CDN rules. If you'd prefer, you can skip this and verify your installation manually",
                             url:
                               "https://plausible.io/docs/troubleshoot-integration#how-to-manually-check-your-integration"
                           }
                         ]
                       } =
                         Checks.run(url_to_verify, expected_domain, "manual",
                           report_to: nil,
                           async?: false,
                           slowdown: 0
                         )
                         |> Checks.interpret_diagnostics()

        assert 2 == :atomics.get(verification_counter, 1)
      end

      for {installation_type, expected_recommendation} <- [
            {"wordpress",
             "Please make sure you've enabled the plugin, or verify your installation manually"},
            {"gtm",
             "Please make sure you've configured the GTM template correctly, or verify your installation manually"},
            {"npm",
             "Please make sure you've initialized Plausible on your site, or verify your installation manually"},
            {"manual",
             "Please make sure you've copied the snippet to the head of your site, or verify your installation manually"}
          ] do
        test "returns error \"We couldn't detect Plausible on your site\" when plausible_is_on_window is false (with best guess recommendation for installation type: #{installation_type})" do
          expected_domain = "example.com"
          url_to_verify = "https://#{expected_domain}"
          stub_lookup_a_records(expected_domain)

          verification_counter =
            stub_verification_result(%{
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
                               url:
                                 "https://plausible.io/docs/troubleshoot-integration#how-to-manually-check-your-integration"
                             }
                           ]
                         } =
                           Checks.run(url_to_verify, expected_domain, unquote(installation_type),
                             report_to: nil,
                             async?: false,
                             slowdown: 0
                           )
                           |> Checks.interpret_diagnostics()

          assert 2 == :atomics.get(verification_counter, 1)
        end

        test "falls back to error \"We couldn't detect Plausible on your site\" when no other case matches (with best guess recommendation for installation type: #{installation_type}), sends diagnostics to Sentry" do
          expected_domain = "example.com"
          url_to_verify = "https://#{expected_domain}"
          stub_lookup_a_records(expected_domain)

          verification_counter =
            stub_verification_result(%{
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
                               url:
                                 "https://plausible.io/docs/troubleshoot-integration#how-to-manually-check-your-integration"
                             }
                           ]
                         } =
                           Checks.run(url_to_verify, expected_domain, unquote(installation_type),
                             report_to: nil,
                             async?: false,
                             slowdown: 0
                           )
                           |> Checks.interpret_diagnostics()

          assert 2 == :atomics.get(verification_counter, 1)
        end
      end
    end

    defp stub_verification_result(js_data) do
      counter = :atomics.new(1, [])

      Req.Test.stub(Plausible.InstallationSupport.Checks.InstallationV2, fn conn ->
        :atomics.add_get(counter, 1, 1)

        conn
        |> put_resp_content_type("application/json")
        |> send_resp(200, Jason.encode!(%{"data" => js_data}))
      end)

      counter
    end

    defp stub_verification_result_i(get_js_data) do
      counter = :atomics.new(1, [])

      Req.Test.stub(Plausible.InstallationSupport.Checks.InstallationV2, fn conn ->
        iteration = :atomics.add_get(counter, 1, 1)
        js_data = get_js_data.(iteration)

        conn
        |> put_resp_content_type("application/json")
        |> send_resp(200, Jason.encode!(%{"data" => js_data}))
      end)

      counter
    end
  end
end
