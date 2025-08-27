defmodule Plausible.InstallationSupport.Verification.DiagnosticsTest do
  use ExUnit.Case
  import Plausible.AssertMatches
  alias Plausible.InstallationSupport.Verification.Diagnostics
  alias Plausible.InstallationSupport.Result

  describe "interpreting diagnostics" do
    for status <- [200, 202] do
      test "success with response status #{status}" do
        expected_domain = "example.com"
        url_to_verify = "https://#{expected_domain}"

        diagnostics = %Diagnostics{
          plausible_is_on_window: true,
          plausible_is_initialized: true,
          test_event: %{
            "normalizedBody" => %{
              "domain" => "example.com"
            },
            "responseStatus" => unquote(status)
          },
          service_error: nil
        }

        assert Diagnostics.interpret(diagnostics, expected_domain, url_to_verify) == %Result{
                 ok?: true
               }
      end
    end

    test "error when it 'succeeds', but only after cache bust" do
      expected_domain = "example.com"
      url_to_verify = "https://#{expected_domain}"

      diagnostics = %Diagnostics{
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

    test "error when test event domain doesn't match expected domain" do
      expected_domain = "example.com"
      url_to_verify = "https://#{expected_domain}"

      diagnostics = %Diagnostics{
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
                       errors: [^any(:string, ~r/.*not for this site.*/)],
                       recommendations: [
                         %{
                           text: ^any(:string, ~r/.*snippet.*/),
                           url:
                             "https://plausible.io/docs/troubleshoot-integration#how-to-manually-check-your-integration"
                         }
                       ]
                     } = Diagnostics.interpret(diagnostics, expected_domain, url_to_verify)
    end

    test "error when proxy network error occurs" do
      expected_domain = "example.com"
      url_to_verify = "https://#{expected_domain}"

      diagnostics = %Diagnostics{
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

    test "error when plausible network error occurs" do
      expected_domain = "example.com"
      url_to_verify = "https://#{expected_domain}"

      diagnostics = %Diagnostics{
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

    test "error when disallowed by CSP" do
      expected_domain = "example.com"
      url_to_verify = "https://#{expected_domain}"

      diagnostics = %Diagnostics{
        disallowed_by_csp: true,
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

    test "error when GTM selected and cookie banner likely" do
      expected_domain = "example.com"
      url_to_verify = "https://#{expected_domain}"

      diagnostics = %Diagnostics{
        selected_installation_type: "gtm",
        cookie_banner_likely: true,
        service_error: nil
      }

      assert_matches %Result{
                       ok?: false,
                       errors: [^any(:string, ~r/.*couldn't verify.*/)],
                       recommendations: [
                         %{
                           text: ^any(:string, ~r/.*cookie consent banner.*/),
                           url:
                             "https://plausible.io/docs/troubleshoot-integration#how-to-manually-check-your-integration"
                         }
                       ]
                     } = Diagnostics.interpret(diagnostics, expected_domain, url_to_verify)
    end

    for error_code <- [:domain_not_found, :invalid_url] do
      test "error when DNS check fails (#{error_code})" do
        expected_domain = "example.com"
        url_to_verify = "https://#{expected_domain}"

        diagnostics = %Diagnostics{
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

    test "error when Browserless encounters a network error during verification" do
      expected_domain = "example.com"
      url_to_verify = "https://#{expected_domain}?plausible_verification=123123123"

      diagnostics = %Diagnostics{
        plausible_is_on_window: nil,
        plausible_is_initialized: nil,
        service_error: "net::ERR_CONNECTION_CLOSED at https://example.com"
      }

      assert_matches %Result{
                       ok?: false,
                       data: %{offer_custom_url_input: true},
                       errors: [
                         ^any(
                           :string,
                           ~r/.*couldn't verify your website at https:\/\/#{expected_domain}$/
                         )
                       ],
                       recommendations: [
                         %{
                           text: ^any(:string, ~r/.*verify your integration manually.*/),
                           url:
                             "https://plausible.io/docs/troubleshoot-integration#how-to-manually-check-your-integration"
                         }
                       ]
                     } = Diagnostics.interpret(diagnostics, expected_domain, url_to_verify)
    end

    test "error when plausible not installed and page.goto(url) response is not 200" do
      expected_domain = "example.com"
      url_to_verify = "https://#{expected_domain}?plausible_verification=123123123"

      diagnostics = %Diagnostics{
        plausible_is_on_window: false,
        plausible_is_initialized: nil,
        response_status: 403
      }

      assert_matches %Result{
                       ok?: false,
                       data: %{offer_custom_url_input: true},
                       errors: [
                         ^any(
                           :string,
                           ~r/.*could not load your website.*/
                         )
                       ],
                       recommendations: [
                         %{
                           text:
                             ^any(
                               :string,
                               ~r/https:\/\/example.com.*403.*verify your installation manually/
                             ),
                           url:
                             "https://plausible.io/docs/troubleshoot-integration#how-to-manually-check-your-integration"
                         }
                       ]
                     } = Diagnostics.interpret(diagnostics, expected_domain, url_to_verify)
    end

    test "unknown error when no specific case matches" do
      expected_domain = "example.com"
      url_to_verify = "https://#{expected_domain}"

      diagnostics = %Diagnostics{
        plausible_is_on_window: false,
        plausible_is_initialized: false,
        response_status: 200,
        service_error: nil
      }

      assert_matches %Result{
                       ok?: false,
                       errors: [^any(:string, ~r/.*integration is not working.*/)],
                       recommendations: [
                         %{
                           text: ^any(:string, ~r/.*manually check.*/),
                           url:
                             "https://plausible.io/docs/troubleshoot-integration#how-to-manually-check-your-integration"
                         }
                       ]
                     } = Diagnostics.interpret(diagnostics, expected_domain, url_to_verify)
    end
  end
end
