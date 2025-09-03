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
          randomized_diagnostics(
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
          )

        assert Diagnostics.interpret(diagnostics, expected_domain, url_to_verify) == %Result{
                 ok?: true
               }
      end
    end

    test "returns error when it 'succeeds', but only after cache bust" do
      expected_domain = "example.com"
      url_to_verify = "https://#{expected_domain}"

      diagnostics =
        randomized_diagnostics(
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
        )

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
          randomized_diagnostics(
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
          )

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
        randomized_diagnostics(
          plausible_is_on_window: true,
          plausible_is_initialized: true,
          test_event: %{
            "requestUrl" => "https://proxy.example.com/event",
            "responseStatus" => 500
          },
          service_error: nil
        )

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
        randomized_diagnostics(
          plausible_is_on_window: true,
          plausible_is_initialized: true,
          test_event: %{
            "requestUrl" => PlausibleWeb.Endpoint.url() <> "/api/event",
            "responseStatus" => 500
          },
          service_error: nil
        )

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

    test "returns error when Plausible domain is disallowed by CSP" do
      expected_domain = "example.com"
      url_to_verify = "https://#{expected_domain}"

      diagnostics =
        randomized_diagnostics(
          disallowed_by_csp: true,
          test_event: nil,
          service_error: nil
        )

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
          randomized_diagnostics(
            plausible_is_on_window: nil,
            plausible_is_initialized: nil,
            service_error: unquote(error_code)
          )

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
        randomized_diagnostics(
          plausible_is_on_window: nil,
          plausible_is_initialized: nil,
          service_error: "net::ERR_CONNECTION_CLOSED at https://example.com"
        )

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

    test "returns error when Plausible not installed and website response status is not 200, offers custom URL input" do
      expected_domain = "example.com"
      url_to_verify = "https://#{expected_domain}?plausible_verification=123123123"

      diagnostics =
        randomized_diagnostics(
          disallowed_by_csp: false,
          plausible_is_on_window: false,
          plausible_is_initialized: false,
          test_event: %{"error" => "Timed out"},
          response_status: 403,
          service_error: nil
        )

      assert_matches %Result{
                       ok?: false,
                       data: %{offer_custom_url_input: true},
                       errors: [
                         ^any(
                           :string,
                           ~r/.*couldn't verify your website at https:\/\/#{expected_domain}.*/
                         )
                       ],
                       recommendations: [
                         %{
                           text:
                             ^any(
                               :string,
                               ~r/403 error.*firewall.*authentication.*CDN.*verify your integration manually/
                             ),
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
          randomized_diagnostics(
            response_status: 200,
            disallowed_by_csp: false,
            plausible_is_on_window: false,
            service_error: nil,
            test_event: %{"error" => "Timed out"},
            selected_installation_type: unquote(installation_type)
          )

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
          randomized_diagnostics(
            selected_installation_type: unquote(installation_type),
            disallowed_by_csp: nil,
            response_status: nil,
            disallowed_by_csp: nil,
            service_error: nil,
            test_event: nil
          )

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

  # creates a randomized diagnostics struct, and overwrites only the fields defined in opts
  defp randomized_diagnostics(opts) do
    selected_installation_type =
      Keyword.get(
        opts,
        :selected_installation_type,
        Enum.random(["npm", "gtm", "wordpress", "manual", nil])
      )

    disallowed_by_csp = Keyword.get(opts, :disallowed_by_csp, Enum.random([true, false, nil]))

    plausible_is_on_window =
      Keyword.get(opts, :plausible_is_on_window, Enum.random([true, false, nil]))

    plausible_is_initialized =
      Keyword.get(opts, :plausible_is_initialized, Enum.random([true, false, nil]))

    plausible_version =
      Keyword.get(opts, :plausible_version, Enum.random([Enum.random(1..100), nil]))

    plausible_variant =
      Keyword.get(opts, :plausible_variant, Enum.random(["npm", "web", "random string", nil]))

    diagnostics_are_from_cache_bust =
      Keyword.get(opts, :diagnostics_are_from_cache_bust, Enum.random([true, false, nil]))

    test_event =
      Keyword.get(
        opts,
        :test_event,
        Enum.random([
          %{
            "normalizedBody" => %{"domain" => Enum.random(["example.com", nil])},
            "responseStatus" => Enum.random([200, 202, 403, 404, 500, nil]),
            "requestUrl" => Enum.random(["https://example.com/api/event", "https://plausible.io/api/event", nil])
          },
          nil
        ])
      )

    cookies_consent_result =
      Keyword.get(
        opts,
        :cookies_consent_result,
        Enum.random([
          %{"handled" => nil, "cmp" => "cookiebot"},
          %{"handled" => false, "error" => %{"message" => "Unknown error"}},
          %{"handled" => nil, "engineLifecycle" => "not-started"},
          nil
        ])
      )

    response_status =
      Keyword.get(opts, :response_status, Enum.random([200, 202, 403, 404, 500, nil]))

    service_error =
      Keyword.get(
        opts,
        :service_error,
        Enum.random([
          "net::ERR_CONNECTION_CLOSED at https://example.com",
          :domain_not_found,
          :invalid_url,
          nil
        ])
      )

    attempts = Keyword.get(opts, :attempts, Enum.random([1, 2, 3, nil]))
    %Diagnostics{
      selected_installation_type: selected_installation_type,
      disallowed_by_csp: disallowed_by_csp,
      plausible_is_on_window: plausible_is_on_window,
      plausible_is_initialized: plausible_is_initialized,
      plausible_version: plausible_version,
      plausible_variant: plausible_variant,
      diagnostics_are_from_cache_bust: diagnostics_are_from_cache_bust,
      test_event: test_event,
      cookies_consent_result: cookies_consent_result,
      response_status: response_status,
      service_error: service_error,
      attempts: attempts
    }
  end
end
