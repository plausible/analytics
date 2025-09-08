defmodule Plausible.InstallationSupport.Verification.DiagnosticsTest do
  use ExUnit.Case
  import Plausible.AssertMatches
  alias Plausible.InstallationSupport.Verification.Diagnostics
  alias Plausible.InstallationSupport.Result

  describe "interpreting diagnostics" do
    for status <- [200, 202] do
      test "returns success if test event response status is #{status} and domain is as expected" do
        expected_domain = "example.com"
        url_to_verify = "https://#{expected_domain}"

        diagnostics =
          %Diagnostics{
            plausible_is_on_window: true,
            plausible_is_initialized: true,
            test_event: %{
              "normalizedBody" => %{
                "domain" => "example.com"
              },
              "responseStatus" => unquote(status)
            },
            service_error: nil,
            diagnostics_are_from_cache_bust: nil
          }

        assert Diagnostics.interpret(diagnostics, expected_domain, url_to_verify) == %Result{
                 ok?: true
               }
      end
    end

    test "returns error when it 'succeeds', but only after cache bust" do
      expected_domain = "example.com"
      url_to_verify = "https://#{expected_domain}"

      diagnostics =
        %Diagnostics{
          plausible_is_on_window: true,
          plausible_is_initialized: true,
          test_event: %{
            "normalizedBody" => %{
              "domain" => "example.com"
            },
            "responseStatus" => 200
          },
          diagnostics_are_from_cache_bust: true,
          service_error: nil
        }

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
                     } = Diagnostics.interpret(diagnostics, expected_domain, url_to_verify)
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

        diagnostics =
          %Diagnostics{
            selected_installation_type: unquote(installation_type),
            plausible_is_on_window: true,
            plausible_is_initialized: true,
            test_event: %{
              "normalizedBody" => %{
                "domain" => "wrong-domain.com"
              },
              "responseStatus" => 200
            },
            service_error: nil
          }

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
                       } = Diagnostics.interpret(diagnostics, expected_domain, url_to_verify)
      end
    end

    test "returns error when proxy network error occurs" do
      expected_domain = "example.com"
      url_to_verify = "https://#{expected_domain}"

      diagnostics =
        %Diagnostics{
          plausible_is_on_window: true,
          plausible_is_initialized: true,
          test_event: %{
            "requestUrl" => "https://proxy.example.com/event",
            "responseStatus" => 500
          },
          service_error: nil
        }

      assert_matches %Result{
                       ok?: false,
                       errors: [^any(:string, ~r/.*proxy.*/)],
                       recommendations: [
                         %{
                           text: ^any(:string, ~r/.*proxied.*/),
                           url: "https://plausible.io/docs/proxy/introduction"
                         }
                       ]
                     } = Diagnostics.interpret(diagnostics, expected_domain, url_to_verify)
    end

    test "returns error when Plausible network error occurs" do
      expected_domain = "example.com"
      url_to_verify = "https://#{expected_domain}"

      diagnostics =
        %Diagnostics{
          plausible_is_on_window: true,
          plausible_is_initialized: true,
          test_event: %{
            "requestUrl" => PlausibleWeb.Endpoint.url() <> "/api/event",
            "responseStatus" => 500
          },
          service_error: nil
        }

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
                     } = Diagnostics.interpret(diagnostics, expected_domain, url_to_verify)
    end

    test "returns error when the snippet is not found for manual installation method, it has priority over CSP-related error" do
      expected_domain = "example.com"
      url_to_verify = "https://#{expected_domain}"

      diagnostics =
        %Diagnostics{
          selected_installation_type: "manual",
          tracker_is_in_html: false,
          disallowed_by_csp: true,
          test_event: nil,
          service_error: nil
        }

      assert_matches %Result{
                       ok?: false,
                       errors: ["We couldn't detect Plausible on your site"],
                       recommendations: [
                         %{
                           text:
                             "Please make sure you've copied snippet to the head of your site, or verify your installation manually",
                           url:
                             "https://plausible.io/docs/troubleshoot-integration#how-to-manually-check-your-integration"
                         }
                       ]
                     } = Diagnostics.interpret(diagnostics, expected_domain, url_to_verify)
    end

    test "returns error when Plausible domain is disallowed by CSP" do
      expected_domain = "example.com"
      url_to_verify = "https://#{expected_domain}"

      diagnostics =
        %Diagnostics{
          disallowed_by_csp: true,
          test_event: nil,
          service_error: nil
        }

      assert_matches %Result{
                       ok?: false,
                       errors: [^any(:string, ~r/.*Content Security Policy.*/)],
                       recommendations: [
                         %{
                           text: ^any(:string, ~r/.*plausible\.io domain.*/),
                           url:
                             "https://plausible.io/docs/troubleshoot-integration#does-your-site-use-a-content-security-policy-csp"
                         }
                       ]
                     } = Diagnostics.interpret(diagnostics, expected_domain, url_to_verify)
    end

    for error_code <- [:domain_not_found, :invalid_url] do
      test "returns error when DNS check fails (with error code: #{error_code})" do
        expected_domain = "example.com"
        url_to_verify = "https://#{expected_domain}"

        diagnostics =
          %Diagnostics{
            plausible_is_on_window: nil,
            plausible_is_initialized: nil,
            service_error: unquote(error_code)
          }

        assert_matches %Result{
                         ok?: false,
                         data: %{offer_custom_url_input: true},
                         errors: [
                           ^any(:string, ~r/.*couldn't find your website at #{url_to_verify}.*/)
                         ],
                         recommendations: [
                           %{
                             text: ^any(:string, ~r/.*verify.*manually.*/),
                             url:
                               "https://plausible.io/docs/troubleshoot-integration#how-to-manually-check-your-integration"
                           }
                         ]
                       } = Diagnostics.interpret(diagnostics, expected_domain, url_to_verify)
      end
    end

    test "returns error when there's a network error during verification, offers custom URL input" do
      expected_domain = "example.com"
      url_to_verify = "https://#{expected_domain}?plausible_verification=123123123"

      diagnostics =
        %Diagnostics{
          plausible_is_on_window: nil,
          plausible_is_initialized: nil,
          service_error: "net::ERR_CONNECTION_CLOSED at https://example.com"
        }

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
                     } = Diagnostics.interpret(diagnostics, expected_domain, url_to_verify)
    end

    test "returns error when Plausible not installed and website response status is not 200, offers custom URL input" do
      expected_domain = "example.com"
      url_to_verify = "https://#{expected_domain}?plausible_verification=123123123"

      diagnostics =
        %Diagnostics{
          disallowed_by_csp: false,
          plausible_is_on_window: false,
          plausible_is_initialized: false,
          test_event: %{"error" => "Timed out"},
          response_status: 403,
          service_error: nil
        }

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
                     } = Diagnostics.interpret(diagnostics, expected_domain, url_to_verify)
    end

    for {installation_type, expected_recommendation} <- [
          {"wordpress",
           "Please make sure you've enabled the plugin, or verify your installation manually"},
          {"gtm",
           "Please make sure you've configured the GTM template correctly, or verify your installation manually"},
          {"npm",
           "Please make sure you've initialized Plausible on your site, or verify your installation manually"},
          {"manual",
           "Please make sure you've copied snippet to the head of your site, or verify your installation manually"}
        ] do
      test "returns error \"We couldn't detect Plausible on your site\" when plausible_is_on_window is false (with best guess recommendation for installation type: #{installation_type})" do
        expected_domain = "example.com"
        url_to_verify = "https://#{expected_domain}"

        diagnostics =
          %Diagnostics{
            response_status: 200,
            disallowed_by_csp: false,
            plausible_is_on_window: false,
            service_error: nil,
            test_event: %{"error" => "Timed out"},
            selected_installation_type: unquote(installation_type)
          }

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
                       } = Diagnostics.interpret(diagnostics, expected_domain, url_to_verify)
      end

      test "falls back to error \"We couldn't detect Plausible on your site\" when no other case matches (with best guess recommendation for installation type: #{installation_type}), sends diagnostics to Sentry" do
        expected_domain = "example.com"
        url_to_verify = "https://#{expected_domain}"

        diagnostics =
          %Diagnostics{
            selected_installation_type: unquote(installation_type),
            disallowed_by_csp: nil,
            response_status: nil,
            service_error: nil,
            test_event: nil
          }

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
                       } = Diagnostics.interpret(diagnostics, expected_domain, url_to_verify)
      end
    end
  end
end
