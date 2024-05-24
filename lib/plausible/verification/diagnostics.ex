defmodule Plausible.Verification.Diagnostics do
  @moduledoc """
  Module responsible for translating diagnostics to user-friendly messages and recommendations.
  """
  require Logger

  defstruct plausible_installed?: false,
            snippets_found_in_head: 0,
            snippets_found_in_body: 0,
            snippet_found_after_busting_cache?: false,
            snippet_unknown_attributes?: false,
            disallowed_via_csp?: false,
            service_error: nil,
            body_fetched?: false,
            wordpress_likely?: false,
            gtm_likely?: false,
            callback_status: 0,
            proxy_likely?: false,
            data_domain_mismatch?: false,
            wordpress_plugin?: false

  @type t :: %__MODULE__{}

  defmodule Result do
    @moduledoc """
    Diagnostics interpretation result.
    """
    defstruct ok?: false, errors: [], recommendations: []
    @type t :: %__MODULE__{}
  end

  @spec interpret(t(), String.t()) :: Result.t()
  def interpret(
        %__MODULE__{
          plausible_installed?: true,
          snippets_found_in_head: 1,
          snippets_found_in_body: 0,
          callback_status: callback_status,
          snippet_found_after_busting_cache?: false,
          service_error: nil,
          data_domain_mismatch?: false
        },
        _url
      )
      when callback_status in [200, 202] do
    %Result{ok?: true}
  end

  def interpret(%__MODULE__{plausible_installed?: false, gtm_likely?: true}, _url) do
    %Result{
      ok?: false,
      errors: ["We encountered an issue with your Plausible integration"],
      recommendations: [
        {"As you're using Google Tag Manager, you'll need to use a GTM-specific Plausible snippet",
         "https://plausible.io/docs/google-tag-manager"}
      ]
    }
  end

  def interpret(
        %__MODULE__{
          plausible_installed?: false,
          snippets_found_in_head: 1,
          disallowed_via_csp?: true,
          proxy_likely?: false
        },
        _url
      ) do
    %Result{
      ok?: false,
      errors: ["We encountered an issue with your site's CSP"],
      recommendations: [
        {"Please add plausible.io domain specifically to the allowed list of domains in your Content Security Policy (CSP)",
         "https://plausible.io/docs/troubleshoot-integration"}
      ]
    }
  end

  def interpret(
        %__MODULE__{
          plausible_installed?: false,
          snippets_found_in_head: 0,
          snippets_found_in_body: 0,
          body_fetched?: true,
          service_error: nil,
          wordpress_likely?: false
        },
        _url
      ) do
    %Result{
      ok?: false,
      errors: ["We couldn't find the Plausible snippet on your site"],
      recommendations: [
        {"Please insert the snippet into your site", "https://plausible.io/docs/plausible-script"}
      ]
    }
  end

  def interpret(
        %__MODULE__{
          plausible_installed?: false,
          body_fetched?: false
        },
        url
      ) do
    %Result{
      ok?: false,
      errors: ["We couldn't reach #{url}. Is your site up?"],
      recommendations: [
        {"If your site is running at a different location, please manually check your integration",
         "https://plausible.io/docs/troubleshoot-integration"}
      ]
    }
  end

  def interpret(
        %__MODULE__{
          plausible_installed?: false,
          service_error: service_error
        },
        _url
      )
      when not is_nil(service_error) do
    %Result{
      ok?: false,
      errors: ["We encountered a temporary problem verifying your website"],
      recommendations: [
        {"Please try again in a few minutes or manually check your integration",
         "https://plausible.io/docs/troubleshoot-integration"}
      ]
    }
  end

  def interpret(
        %__MODULE__{
          plausible_installed?: true,
          service_error: nil,
          body_fetched?: false
        },
        url
      ) do
    %Result{
      ok?: false,
      errors: ["We couldn't reach #{url}. Is your site up?"],
      recommendations: [
        {"If your site is running at a different location, please manually check your integration",
         "https://plausible.io/docs/troubleshoot-integration"}
      ]
    }
  end

  def interpret(
        %__MODULE__{
          snippets_found_in_body: 0,
          snippets_found_in_head: 1,
          plausible_installed?: true,
          wordpress_likely?: false,
          callback_status: -1
        },
        _url
      ) do
    %Result{
      ok?: false,
      errors: ["We encountered a problem trying to verify your website"],
      recommendations: [
        {"The integration may be working but as you're running an older version of our script, we cannot verify it automatically. Please manually check your integration or update to use the latest script",
         "https://plausible.io/docs/troubleshoot-integration"}
      ]
    }
  end

  def interpret(
        %__MODULE__{
          snippets_found_in_body: 0,
          snippets_found_in_head: 1,
          plausible_installed?: true,
          wordpress_likely?: true,
          wordpress_plugin?: false,
          callback_status: -1
        },
        _url
      ) do
    %Result{
      ok?: false,
      errors: ["We encountered a problem trying to verify your website"],
      recommendations: [
        {"The integration may be working but as you're running an older version of our script, we cannot verify it automatically. Please install our WordPress plugin to use the built-in proxy",
         "https://plausible.io/wordpress-analytics-plugin"}
      ]
    }
  end

  def interpret(
        %__MODULE__{
          snippets_found_in_body: 0,
          snippets_found_in_head: 1,
          plausible_installed?: true,
          wordpress_likely?: true,
          wordpress_plugin?: true,
          callback_status: -1
        },
        _url
      ) do
    %Result{
      ok?: false,
      errors: ["We encountered a problem trying to verify your website"],
      recommendations: [
        {"The integration may be working but as you're running an older version of our script, we cannot verify it automatically. Please disable and then enable the proxy in our WordPress plugin, then clear your WordPress cache",
         "https://plausible.io/wordpress-analytics-plugin"}
      ]
    }
  end

  def interpret(
        %__MODULE__{
          plausible_installed?: true,
          callback_status: 0,
          proxy_likely?: true
        },
        _url
      ) do
    %Result{
      ok?: false,
      errors: ["We encountered an error with your Plausible proxy"],
      recommendations: [
        {"Please check whether you've configured the /event route correctly",
         "https://plausible.io/docs/proxy/introduction"}
      ]
    }
  end

  def interpret(
        %__MODULE__{
          plausible_installed?: false,
          snippets_found_in_head: 1,
          proxy_likely?: true,
          wordpress_likely?: true,
          wordpress_plugin?: false
        },
        _url
      ) do
    %Result{
      ok?: false,
      errors: ["We encountered an error with your Plausible proxy"],
      recommendations: [
        {"Please re-enable the proxy in our WordPress plugin to start counting your visitors",
         "https://plausible.io/wordpress-analytics-plugin"}
      ]
    }
  end

  def interpret(
        %__MODULE__{
          plausible_installed?: false,
          snippets_found_in_head: 1,
          proxy_likely?: true,
          wordpress_likely?: false
        },
        _url
      ) do
    %Result{
      ok?: false,
      errors: ["We encountered an error with your Plausible proxy"],
      recommendations: [
        {"Please check your proxy configuration to make sure it's set up correctly",
         "https://plausible.io/docs/proxy/introduction"}
      ]
    }
  end

  def interpret(
        %__MODULE__{snippets_found_in_head: count_head, snippets_found_in_body: count_body},
        _url
      )
      when count_head + count_body > 1 do
    %Result{
      ok?: false,
      errors: ["We've found multiple Plausible snippets on your site."],
      recommendations: [
        {"Please ensure that only one snippet is used",
         "https://plausible.io/docs/troubleshoot-integration"}
      ]
    }
  end

  def interpret(
        %__MODULE__{
          plausible_installed?: true,
          callback_status: 202,
          snippet_found_after_busting_cache?: true,
          wordpress_likely?: true,
          wordpress_plugin?: true
        },
        _url
      ) do
    %Result{
      ok?: false,
      errors: ["We encountered an issue with your site cache"],
      recommendations: [
        {"Please clear your WordPress cache to ensure that the latest version of your site is being displayed to all your visitors",
         "https://plausible.io/wordpress-analytics-plugin"}
      ]
    }
  end

  def interpret(
        %__MODULE__{
          plausible_installed?: true,
          callback_status: 202,
          snippet_found_after_busting_cache?: true,
          wordpress_likely?: true,
          wordpress_plugin?: false
        },
        _url
      ) do
    %Result{
      ok?: false,
      errors: ["We encountered an issue with your site cache"],
      recommendations: [
        {"Please install and activate our WordPress plugin to start counting your visitors",
         "https://plausible.io/wordpress-analytics-plugin"}
      ]
    }
  end

  def interpret(
        %__MODULE__{
          plausible_installed?: true,
          callback_status: 202,
          snippet_found_after_busting_cache?: true,
          wordpress_likely?: false
        },
        _url
      ) do
    %Result{
      ok?: false,
      errors: ["We encountered an issue with your site cache"],
      recommendations: [
        {"Please clear your cache (or wait for your provider to clear it) to ensure that the latest version of your site is being displayed to all your visitors",
         "https://plausible.io/docs/troubleshoot-integration"}
      ]
    }
  end

  def interpret(%__MODULE__{snippets_found_in_head: 0, snippets_found_in_body: n}, _url)
      when n >= 1 do
    %Result{
      ok?: false,
      errors: ["Plausible snippet is placed in the body of your site"],
      recommendations: [
        {"Please relocate the snippet to the header of your site",
         "https://plausible.io/docs/troubleshoot-integration"}
      ]
    }
  end

  def interpret(%__MODULE__{data_domain_mismatch?: true}, "https://" <> domain) do
    %Result{
      ok?: false,
      errors: ["Your data-domain is different than #{domain}"],
      recommendations: [
        {"Please ensure that the site in the data-domain attribute is an exact match to the site as you added it to your Plausible account",
         "https://plausible.io/docs/troubleshoot-integration"}
      ]
    }
  end

  def interpret(
        %__MODULE__{
          plausible_installed?: false,
          snippet_unknown_attributes?: true,
          wordpress_likely?: true,
          wordpress_plugin?: true
        },
        _url
      ) do
    %Result{
      ok?: false,
      errors: ["A performance optimization plugin seems to have altered our snippet"],
      recommendations: [
        {"Please whitelist our script in your performance optimization plugin to stop it from changing our snippet",
         "https://plausible.io/wordpress-analytics-plugin "}
      ]
    }
  end

  def interpret(
        %__MODULE__{
          plausible_installed?: false,
          snippet_unknown_attributes?: true,
          wordpress_likely?: true,
          wordpress_plugin?: false
        },
        _url
      ) do
    %Result{
      ok?: false,
      errors: ["A performance optimization plugin seems to have altered our snippet"],
      recommendations: [
        {"Please install and activate our WordPress plugin to avoid the most common plugin conflicts",
         "https://plausible.io/wordpress-analytics-plugin "}
      ]
    }
  end

  def interpret(
        %__MODULE__{
          plausible_installed?: false,
          snippet_unknown_attributes?: true,
          wordpress_likely?: false
        },
        _url
      ) do
    %Result{
      ok?: false,
      errors: ["Something seems to have altered our snippet"],
      recommendations: [
        {"Please manually check your integration to make sure that nothing prevents our script from working",
         "https://plausible.io/docs/troubleshoot-integration"}
      ]
    }
  end

  def interpret(
        %__MODULE__{
          plausible_installed?: true,
          snippets_found_in_head: 0,
          snippets_found_in_body: 0,
          callback_status: callback_status,
          snippet_found_after_busting_cache?: false,
          service_error: nil
        },
        _url
      )
      when callback_status in [200, 202] do
    %Result{ok?: true}
  end

  def interpret(rating, url) do
    Sentry.capture_message("Unhandled case for site verification: #{url}",
      extra: %{
        message: inspect(rating)
      }
    )

    %Result{
      ok?: false,
      errors: ["Your Plausible integration is not working"],
      recommendations: [
        {"Please manually check your integration to make sure that the Plausible snippet has been inserted correctly",
         "https://plausible.io/docs/troubleshoot-integration"}
      ]
    }
  end
end
