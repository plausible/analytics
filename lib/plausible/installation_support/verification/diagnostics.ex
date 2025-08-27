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
            cookie_banner_likely: nil,
            service_error: nil,
            attempts: nil

  @type t :: %__MODULE__{}

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
          plausible_is_on_window: true,
          plausible_is_initialized: true,
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
          plausible_is_on_window: true,
          plausible_is_initialized: true,
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

  @error_unexpected_domain Error.new!(%{
                             message: "Plausible test event is not for this site",
                             recommendation:
                               "Please check that the snippet on your site matches the installation instructions exactly",
                             url:
                               "https://plausible.io/docs/troubleshoot-integration#how-to-manually-check-your-integration"
                           })
  def interpret(
        %__MODULE__{
          plausible_is_on_window: true,
          plausible_is_initialized: true,
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
             domain != expected_domain,
      do: error(@error_unexpected_domain)

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
                                   url:
                                     "https://plausible.io/docs/troubleshoot-integration#how-to-manually-check-your-integration"
                                 })

  def interpret(
        %__MODULE__{
          plausible_is_on_window: true,
          plausible_is_initialized: true,
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

  @error_gtm_selected_maybe_cookie_banner Error.new!(%{
                                            message: "We couldn't verify your website",
                                            recommendation:
                                              "A cookie consent banner may be stopping Plausible from loading on your site. If that is intentional, you'll need to verify that Plausible works manually",
                                            url:
                                              "https://plausible.io/docs/troubleshoot-integration#how-to-manually-check-your-integration"
                                          })
  def interpret(
        %__MODULE__{
          selected_installation_type: "gtm",
          cookie_banner_likely: true,
          service_error: nil
        },
        _expected_domain,
        _url
      ),
      do: error(@error_gtm_selected_maybe_cookie_banner)

  def interpret(%__MODULE__{service_error: service_error}, expected_domain, url)
      when service_error in [:domain_not_found, :invalid_url] do
    attempted_url = if url, do: url, else: "https://#{expected_domain}"

    %Error{
      message: "We couldn't find your website at #{attempted_url}",
      recommendation:
        "Please check that the domain you entered is correct and reachable publicly. If it's intentionally private, you'll need to verify that Plausible works manually",
      url:
        "https://plausible.io/docs/troubleshoot-integration#how-to-manually-check-your-integration"
    }
    |> error()
    |> struct!(data: %{offer_custom_url_input: true})
  end

  def interpret(%__MODULE__{service_error: "net::" <> _}, _expected_domain, url)
      when is_binary(url) do
    attempted_url = String.split(url, "?") |> List.first()

    %Error{
      message: "We couldn't verify your website at #{attempted_url}",
      recommendation:
        "Our verification tool encountered a network error while trying to verify your website. Please verify your integration manually",
      url:
        "https://plausible.io/docs/troubleshoot-integration#how-to-manually-check-your-integration"
    }
    |> error()
    |> struct!(data: %{offer_custom_url_input: true})
  end

  @unknown_error Error.new!(%{
                   message: "Your Plausible integration is not working",
                   recommendation:
                     "Please manually check your integration to make sure that the Plausible snippet has been inserted correctly",
                   url:
                     "https://plausible.io/docs/troubleshoot-integration#how-to-manually-check-your-integration"
                 })
  def interpret(%__MODULE__{} = diagnostics, _expected_domain, url) do
    Sentry.capture_message("Unhandled case for site verification (v2)",
      extra: %{
        message: inspect(diagnostics),
        url: url,
        hash: :erlang.phash2(diagnostics)
      }
    )

    error(@unknown_error)
  end

  defp success() do
    %Result{ok?: true}
  end

  defp error(%Error{} = error) do
    %Result{
      ok?: false,
      errors: [error.message],
      recommendations: [%{text: error.recommendation, url: error.url}]
    }
  end
end
