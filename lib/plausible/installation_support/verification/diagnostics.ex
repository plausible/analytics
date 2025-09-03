defmodule Plausible.InstallationSupport.Verification.Diagnostics do
  @moduledoc """
  Module responsible for translating diagnostics to user-friendly errors and recommendations.
  """
  require Logger

  # in this struct, nil means indeterminate
  defstruct selected_installation_type: nil,
            disallowed_by_csp: nil,
            plausible_is_on_window: nil,
            plausible_is_initialized: nil,
            plausible_version: nil,
            plausible_variant: nil,
            diagnostics_are_from_cache_bust: nil,
            test_event: nil,
            cookies_consent_result: nil,
            response_status: nil,
            service_error: nil,
            attempts: nil

  @type t :: %__MODULE__{}

  @verify_manually_url "https://plausible.io/docs/troubleshoot-integration#how-to-manually-check-your-integration"

  alias Plausible.InstallationSupport.Result

  defmodule Error do
    @moduledoc """
    Error that has compile-time enforced checks for the attributes.
    """

    @enforce_keys [:message, :recommendation]
    defstruct [:message, :recommendation, :url]

    def new!(attrs) do
      message = Map.fetch!(attrs, :message)

      if String.ends_with?(message, ".") do
        raise ArgumentError, "Error message must not end with a period: #{inspect(message)}"
      end

      if String.ends_with?(attrs[:recommendation], ".") do
        raise ArgumentError,
              "Error recommendation must not end with a period: #{inspect(attrs[:recommendation])}"
      end

      if is_binary(attrs[:url]) and not String.starts_with?(attrs[:url], "https://plausible.io") do
        raise ArgumentError,
              "Recommendation url must start with 'https://plausible.io': #{inspect(attrs[:url])}"
      end

      struct!(__MODULE__, attrs)
    end
  end

  @error_succeeds_only_after_cache_bust Error.new!(%{
                                          message: "We detected an issue with your site's cache",
                                          recommendation:
                                            "Please clear the cache for your site to ensure that your visitors will load the latest version of your site that has Plausible correctly installed",
                                          url:
                                            "https://plausible.io/docs/troubleshoot-integration#have-you-cleared-the-cache-of-your-site"
                                        })

  @spec interpret(t(), String.t(), String.t()) :: Result.t()
  def interpret(
        %__MODULE__{
          test_event: %{
            "normalizedBody" => %{
              "domain" => domain
            },
            "responseStatus" => response_status
          },
          service_error: nil,
          diagnostics_are_from_cache_bust: true
        },
        expected_domain,
        _url
      )
      when response_status in [200, 202] and
             domain == expected_domain,
      do: error(@error_succeeds_only_after_cache_bust)

  def interpret(
        %__MODULE__{
          test_event: %{
            "normalizedBody" => %{
              "domain" => domain
            },
            "responseStatus" => response_status
          },
          service_error: nil
        },
        expected_domain,
        _url
      )
      when response_status in [200, 202] and
             domain == expected_domain,
      do: success()

  def interpret(
        %__MODULE__{
          test_event: %{
            "normalizedBody" => %{
              "domain" => domain
            },
            "responseStatus" => response_status
          },
          service_error: nil,
          selected_installation_type: selected_installation_type
        },
        expected_domain,
        _url
      )
      when response_status in [200, 202] and
             domain != expected_domain,
      do: error_unexpected_domain(selected_installation_type)

  @error_proxy_network_error Error.new!(%{
                               message:
                                 "We got an unexpected response from the proxy you are using for Plausible",
                               recommendation:
                                 "Please check that you've configured the proxied /event route correctly",
                               url: "https://plausible.io/docs/proxy/introduction"
                             })
  @error_plausible_network_error Error.new!(%{
                                   message: "We couldn't verify your website",
                                   recommendation:
                                     "Please try verifying again in a few minutes, or verify your installation manually",
                                   url: @verify_manually_url
                                 })

  def interpret(
        %__MODULE__{
          test_event: %{
            "requestUrl" => request_url,
            "responseStatus" => response_status
          },
          service_error: nil
        },
        _expected_domain,
        _url
      )
      when response_status not in [200, 202] and is_binary(request_url) do
    proxying? = not String.starts_with?(request_url, PlausibleWeb.Endpoint.url())

    if proxying? do
      error(@error_proxy_network_error)
    else
      error(@error_plausible_network_error)
    end
  end

  @error_csp_disallowed Error.new!(%{
                          message:
                            "We encountered an issue with your site's Content Security Policy (CSP)",
                          recommendation:
                            "Please add plausible.io domain specifically to the allowed list of domains in your site's CSP",
                          url:
                            "https://plausible.io/docs/troubleshoot-integration#does-your-site-use-a-content-security-policy-csp"
                        })
  def interpret(
        %__MODULE__{
          disallowed_by_csp: true,
          service_error: nil
        },
        _expected_domain,
        _url
      ),
      do: error(@error_csp_disallowed)

  @error_domain_not_found Error.new!(%{
                            message: "We couldn't find your website at <%= @attempted_url %>",
                            recommendation:
                              "Please check that the domain you entered is correct and reachable publicly. If it's intentionally private, you'll need to verify that Plausible works manually",
                            url: @verify_manually_url
                          })

  def interpret(%__MODULE__{service_error: service_error}, expected_domain, url)
      when service_error in [:domain_not_found, :invalid_url] do
    attempted_url = if url, do: url, else: "https://#{expected_domain}"

    @error_domain_not_found
    |> error(attempted_url: attempted_url)
    |> struct!(data: %{offer_custom_url_input: true})
  end

  @error_browserless_network Error.new!(%{
                               message:
                                 "We couldn't verify your website at <%= @attempted_url %>",
                               recommendation:
                                 "Our verification tool encountered a network error while trying to verify your website. Please verify your integration manually",
                               url: @verify_manually_url
                             })

  def interpret(%__MODULE__{service_error: "net::" <> _}, _expected_domain, url)
      when is_binary(url) do
    attempted_url = shorten_url(url)

    @error_browserless_network
    |> error(attempted_url: attempted_url)
    |> struct!(data: %{offer_custom_url_input: true})
  end

  @error_non_200_page_response Error.new!(%{
                                 message:
                                   "We couldn't verify your website at <%= @attempted_url %>",
                                 recommendation:
                                   "Our verification tool encountered a <%= @page_response_status %> error. Please check for anything that might be blocking it from reaching your site, like a firewall, authentication requirements, or CDN rules. If you'd prefer, you can skip this and verify your integration manually",
                                 url: @verify_manually_url
                               })

  def interpret(
        %__MODULE__{
          plausible_is_on_window: plausible_is_on_window,
          plausible_is_initialized: plausible_is_initialized,
          response_status: page_response_status
        },
        _expected_domain,
        url
      )
      when is_binary(url) and page_response_status not in [200, nil] and
             plausible_is_on_window != true and
             plausible_is_initialized != true do
    attempted_url = shorten_url(url)

    @error_non_200_page_response
    |> error(attempted_url: attempted_url, page_response_status: page_response_status)
    |> struct!(data: %{offer_custom_url_input: true})
  end

  def interpret(
        %__MODULE__{
          selected_installation_type: selected_installation_type,
          plausible_is_on_window: false,
          service_error: nil
        },
        _expected_domain,
        _url
      ),
      do: error_plausible_not_found(selected_installation_type)

  def interpret(%__MODULE__{} = diagnostics, _expected_domain, url) do
    Sentry.capture_message("Unhandled case for site verification (v2)",
      extra: %{
        message: inspect(diagnostics),
        url: url,
        hash: :erlang.phash2(diagnostics)
      }
    )

    error_plausible_not_found(diagnostics.selected_installation_type)
  end

  @message_plausible_not_found "We couldn't detect Plausible on your site"
  @error_plausible_not_found_for_manual Error.new!(%{
                                          message: @message_plausible_not_found,
                                          recommendation:
                                            "Please make sure you've copied snippet to the head of your site, or verify your installation manually",
                                          url: @verify_manually_url
                                        })
  @error_plausible_not_found_for_npm Error.new!(%{
                                       message: @message_plausible_not_found,
                                       recommendation:
                                         "Please make sure you've initialized Plausible on your site, or verify your installation manually",
                                       url: @verify_manually_url
                                     })
  @error_plausible_not_found_for_gtm Error.new!(%{
                                       message: @message_plausible_not_found,
                                       recommendation:
                                         "Please make sure you've configured the GTM template correctly, or verify your installation manually",
                                       url: @verify_manually_url
                                     })
  @error_plausible_not_found_for_wordpress Error.new!(%{
                                             message: @message_plausible_not_found,
                                             recommendation:
                                               "Please make sure you've enabled the plugin, or verify your installation manually",
                                             url: @verify_manually_url
                                           })
  defp error_plausible_not_found(selected_installation_type) do
    case selected_installation_type do
      "npm" -> error(@error_plausible_not_found_for_npm)
      "gtm" -> error(@error_plausible_not_found_for_gtm)
      "wordpress" -> error(@error_plausible_not_found_for_wordpress)
      _ -> error(@error_plausible_not_found_for_manual)
    end
  end

  @unexpected_domain_message "Plausible test event is not for this site"
  @error_unexpected_domain_for_manual Error.new!(%{
                                        message: @unexpected_domain_message,
                                        recommendation:
                                          "Please check that the snippet on your site matches the installation instructions exactly, or verify your installation manually",
                                        url: @verify_manually_url
                                      })

  @error_unexpected_domain_for_npm Error.new!(%{
                                     message: @unexpected_domain_message,
                                     recommendation:
                                       "Please check that you've initialized Plausible with the correct domain, or verify your installation manually",
                                     url: @verify_manually_url
                                   })

  @error_unexpected_domain_for_gtm Error.new!(%{
                                     message: @unexpected_domain_message,
                                     recommendation:
                                       "Please check that you've entered the ID in the GTM template correctly, or verify your installation manually",
                                     url: @verify_manually_url
                                   })

  @error_unexpected_domain_for_wordpress Error.new!(%{
                                           message: @unexpected_domain_message,
                                           recommendation:
                                             "Please check that you've installed the WordPress plugin correctly, or verify your installation manually",
                                           url: @verify_manually_url
                                         })
  defp error_unexpected_domain(selected_installation_type) do
    case selected_installation_type do
      "npm" -> error(@error_unexpected_domain_for_npm)
      "gtm" -> error(@error_unexpected_domain_for_gtm)
      "wordpress" -> error(@error_unexpected_domain_for_wordpress)
      _ -> error(@error_unexpected_domain_for_manual)
    end
  end

  defp shorten_url(url) do
    String.split(url, "?") |> List.first()
  end

  defp success() do
    %Result{ok?: true}
  end

  defp error(%Error{} = error, assigns \\ []) do
    message = EEx.eval_string(error.message, assigns: assigns)
    recommendation = EEx.eval_string(error.recommendation, assigns: assigns)

    %Result{
      ok?: false,
      errors: [message],
      recommendations: [%{text: recommendation, url: error.url}]
    }
  end
end
