defmodule Plausible.InstallationSupport.LegacyVerification.Errors do
  @moduledoc """
  A go-to definition of all legacy verification errors
  """

  @errors %{
    gtm: %{
      message: "We encountered an issue with your Plausible integration",
      recommendation:
        "As you're using Google Tag Manager, you'll need to use a GTM-specific Plausible snippet",
      url: "https://plausible.io/docs/google-tag-manager"
    },
    gtm_cookie_banner: %{
      message: "We couldn't verify your website",
      recommendation:
        "As you're using Google Tag Manager, you'll need to use a GTM-specific Plausible snippet. Please make sure no cookie consent banner is blocking our script",
      url: "https://plausible.io/docs/google-tag-manager"
    },
    csp: %{
      message: "We encountered an issue with your site's CSP",
      recommendation:
        "Please add plausible.io domain specifically to the allowed list of domains in your Content Security Policy (CSP)",
      url:
        "https://plausible.io/docs/troubleshoot-integration#does-your-site-use-a-content-security-policy-csp"
    },
    unreachable: %{
      message: "We couldn't reach your site",
      recommendation:
        "If your site is running at a different location, please manually check your integration",
      url: "https://plausible.io/docs/troubleshoot-integration"
    },
    no_snippet: %{
      message: "We couldn't find the Plausible snippet",
      recommendation: "Please insert the snippet into your site",
      url: "https://plausible.io/docs/plausible-script"
    },
    no_snippet_wp: %{
      message: "We couldn't find the Plausible snippet on your site",
      recommendation:
        "Please install and activate our WordPress plugin to start counting your visitors",
      url: "https://plausible.io/wordpress-analytics-plugin"
    },
    temporary: %{
      message: "We encountered a temporary problem",
      recommendation: "Please try again in a few minutes or manually check your integration",
      url:
        "https://plausible.io/docs/troubleshoot-integration#how-to-manually-check-your-integration"
    },
    generic: %{
      message: "We couldn't automatically verify your website",
      recommendation:
        "Please manually check your integration by following the instructions provided",
      url:
        "https://plausible.io/docs/troubleshoot-integration#how-to-manually-check-your-integration"
    },
    old_script_wp_no_plugin: %{
      message: "We couldn't verify your website",
      recommendation:
        "You're running an older version of our script so we cannot verify it. Please use our WordPress plugin instead",
      url: "https://plausible.io/wordpress-analytics-plugin"
    },
    old_script_wp_plugin: %{
      message: "We couldn't verify your website",
      recommendation:
        "You're running an older version of our script so we cannot verify it. Please re-enable the proxy in our plugin",
      url: "https://plausible.io/wordpress-analytics-plugin"
    },
    proxy_misconfigured: %{
      message: "We encountered an error with your Plausible proxy",
      recommendation: "Please check whether you've configured the /event route correctly",
      url: "https://plausible.io/docs/proxy/introduction"
    },
    proxy_wp_no_plugin: %{
      message: "We encountered an error with your Plausible proxy",
      recommendation:
        "Please re-enable the proxy in our WordPress plugin to start counting your visitors",
      url: "https://plausible.io/wordpress-analytics-plugin"
    },
    proxy_general: %{
      message: "We encountered an error with your Plausible proxy",
      recommendation: "Please check your proxy configuration to make sure it's set up correctly",
      url: "https://plausible.io/docs/proxy/introduction"
    },
    multiple_snippets: %{
      message: "We've found multiple Plausible snippets",
      recommendation: "Please ensure that only one snippet is used",
      url:
        "https://plausible.io/docs/troubleshoot-integration#did-you-insert-multiple-plausible-snippets-into-your-site"
    },
    cache_wp_plugin: %{
      message: "We encountered an issue with your site cache",
      recommendation:
        "Please clear your WordPress cache to ensure that the latest version is displayed to your visitors",
      url: "https://plausible.io/wordpress-analytics-plugin"
    },
    cache_wp_no_plugin: %{
      message: "We encountered an issue with your site cache",
      recommendation:
        "Please install and activate our WordPress plugin to start counting your visitors",
      url: "https://plausible.io/wordpress-analytics-plugin"
    },
    cache_general: %{
      message: "We encountered an issue with your site cache",
      recommendation:
        "Please clear your cache (or wait for your provider to clear it) to ensure that the latest version is displayed to your visitors",
      url:
        "https://plausible.io/docs/troubleshoot-integration#have-you-cleared-the-cache-of-your-site"
    },
    snippet_in_body: %{
      message: "Plausible snippet is placed in the body",
      recommendation: "Please relocate the snippet to the header of your site",
      url: "https://plausible.io/docs/troubleshoot-integration"
    },
    different_data_domain: %{
      message: "Your data-domain is different",
      recommendation: "Please ensure that the data-domain matches <%= @domain %> exactly",
      url:
        "https://plausible.io/docs/troubleshoot-integration#have-you-added-the-correct-data-domain-attribute-in-the-plausible-snippet"
    },
    illegal_attrs_wp_plugin: %{
      message: "A performance optimization plugin seems to have altered our snippet",
      recommendation:
        "Please whitelist our script in your performance optimization plugin to stop it from changing our snippet",
      url:
        "https://plausible.io/docs/troubleshoot-integration#has-some-other-plugin-altered-our-snippet"
    },
    illegal_attrs_wp_no_plugin: %{
      message: "A performance optimization plugin seems to have altered our snippet",
      recommendation:
        "Please install and activate our WordPress plugin to avoid the most common plugin conflicts",
      url: "https://plausible.io/wordpress-analytics-plugin"
    },
    illegal_attrs_general: %{
      message: "Something seems to have altered our snippet",
      recommendation:
        "Please manually check your integration to make sure that nothing prevents our script from working",
      url:
        "https://plausible.io/docs/troubleshoot-integration#has-some-other-plugin-altered-our-snippet"
    },
    unknown: %{
      message: "Your Plausible integration is not working",
      recommendation:
        "Please manually check your integration to make sure that the Plausible snippet has been inserted correctly",
      url:
        "https://plausible.io/docs/troubleshoot-integration#how-to-manually-check-your-integration"
    }
  }

  def all(), do: @errors

  for {_, %{message: message, recommendation: recommendation} = e} <- @errors do
    if String.ends_with?(message, ".") or String.ends_with?(recommendation, ".") do
      raise "Error message/recommendation should not end with a period: #{inspect(e)}"
    end
  end
end
