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
            service_error: nil

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

  @supported_variants ["web", "npm"]

  @error_unexpected_domain Error.new!(%{
                             message: "Plausible test event is not for this site",
                             recommendation:
                               "Please check that the snippet on your site matches the installation instructions exactly",
                             url:
                               "https://plausible.io/docs/troubleshoot-integration#how-to-manually-check-your-integration"
                           })
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
          plausible_variant: plausible_variant,
          test_event: %{
            "normalizedBody" => %{
              "domain" => domain
            },
            "responseStatus" => response_status
          },
          service_error: nil,
          diagnostics_are_from_cache_bust: diagnostics_are_from_cache_bust
        } = diagnostics,
        expected_domain,
        url
      )
      when response_status in [200, 202] do
    domain_is_expected? = domain == expected_domain

    tracker_is_version_2? = plausible_variant in @supported_variants
    tracker_is_maybe_legacy? = is_nil(plausible_variant)

    cond do
      (tracker_is_version_2? or tracker_is_maybe_legacy?) and
        domain_is_expected? and diagnostics_are_from_cache_bust ->
        error(@error_succeeds_only_after_cache_bust)

      (tracker_is_version_2? or tracker_is_maybe_legacy?) and
          domain_is_expected? ->
        success()

      (tracker_is_version_2? or tracker_is_maybe_legacy?) and
          not domain_is_expected? ->
        error(@error_unexpected_domain)

      true ->
        unknown_error(diagnostics, url)
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
      ) do
    error(@error_csp_disallowed)
  end

  def interpret(%__MODULE__{} = diagnostics, _expected_domain, url),
    do: unknown_error(diagnostics, url)

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

  @unknown_error Error.new!(%{
                   message: "Your Plausible integration is not working",
                   recommendation:
                     "Please manually check your integration to make sure that the Plausible snippet has been inserted correctly",
                   url:
                     "https://plausible.io/docs/troubleshoot-integration#how-to-manually-check-your-integration"
                 })
  defp unknown_error(diagnostics, url) do
    Sentry.capture_message("Unhandled case for site verification",
      extra: %{
        message: inspect(diagnostics),
        url: url,
        hash: :erlang.phash2(diagnostics)
      }
    )

    error(@unknown_error)
  end
end
