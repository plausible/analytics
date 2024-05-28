defmodule Plausible.Verification.Errors do
  @moduledoc """
  A go-to definition of all verification errors
  """

  @errors %{
    gtm: %{
      message: "We encountered an issue with your Plausible integration",
      recommendation:
        "As you're using Google Tag Manager, you'll need to use a GTM-specific Plausible snippet",
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
      message: "We couldn't reach <%= @url %>. Is your site up?",
      recommendation:
        "If your site is running at a different location, please manually check your integration",
      url: "https://plausible.io/docs/troubleshoot-integration"
    },
    no_snippet: %{
      message: "We couldn't find the Plausible snippet on your site",
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
      message: "We encountered a temporary problem verifying your website",
      recommendation: "Please try again in a few minutes or manually check your integration",
      url:
        "https://plausible.io/docs/troubleshoot-integration#how-to-manually-check-your-integration"
    },
    old_script: %{
      message: "We encountered a problem trying to verify your website",
      recommendation:
        "The integration may be working but as you're running an older version of our script, we cannot verify it automatically. Please manually check your integration or update to use the latest script",
      url:
        "https://plausible.io/docs/troubleshoot-integration#are-you-using-an-older-version-of-our-script"
    },
    old_script_wp_no_plugin: %{
      message: "We encountered a problem trying to verify your website",
      recommendation:
        "The integration may be working but as you're running an older version of our script, we cannot verify it automatically. Please install our WordPress plugin to use the built-in proxy",
      url: "https://plausible.io/wordpress-analytics-plugin"
    },
    old_script_wp_plugin: %{
      message: "We encountered a problem trying to verify your website",
      recommendation:
        "The integration may be working but as you're running an older version of our script, we cannot verify it automatically. Please disable and then enable the proxy in our WordPress plugin, then clear your WordPress cache",
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
      message: "We've found multiple Plausible snippets on your site.",
      recommendation: "Please ensure that only one snippet is used",
      url:
        "https://plausible.io/docs/troubleshoot-integration#did-you-insert-multiple-plausible-snippets-into-your-site"
    },
    cache_wp_plugin: %{
      message: "We encountered an issue with your site cache",
      recommendation:
        "Please clear your WordPress cache to ensure that the latest version of your site is being displayed to all your visitors",
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
        "Please clear your cache (or wait for your provider to clear it) to ensure that the latest version of your site is being displayed to all your visitors",
      url:
        "https://plausible.io/docs/troubleshoot-integration#have-you-cleared-the-cache-of-your-site"
    },
    snippet_in_body: %{
      message: "Plausible snippet is placed in the body of your site",
      recommendation: "Please relocate the snippet to the header of your site",
      url: "https://plausible.io/docs/troubleshoot-integration"
    },
    different_data_domain: %{
      message: "Your data-domain is different than <%= @domain %>",
      recommendation:
        "Please ensure that the site in the data-domain attribute is an exact match to the site as you added it to your Plausible account",
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
end
