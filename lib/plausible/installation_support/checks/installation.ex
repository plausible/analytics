defmodule Plausible.InstallationSupport.Checks.Installation do
  require Logger

  @verifier_code_path "priv/tracker/installation_support/verifier-v1.js"
  @external_resource @verifier_code_path

  # On CI, the file might not be present for static checks so we default to empty string
  @verifier_code (case File.read(Application.app_dir(:plausible, @verifier_code_path)) do
                    {:ok, content} -> content
                    {:error, _} -> ""
                  end)

  # Puppeteer wrapper function that executes the vanilla JS verifier code.

  # ### NO AUTOMATIC TEST COVERAGE

  # Unfortunately, as things stand today, this Puppeteer wrapper logic
  # cannot be tested without spinning up a real Browserless instance or
  # bringing in a bunch of test deps for Puppeteer. Therefore, take extra
  # care when changing this and make sure to run manual tests on local
  # browserless (`make browserless`) before releasing an update.

  # ### TRICKY: Handling client side JS navigation.

  # We've seen numerous cases where client JS navigates or refreshes the
  # page after load. Any such JS behaviour destroys the Puppeteer page
  # context, meaning that our verifier execution gets interrupted and we
  # end up in the `catch` clause.

  # To make our best effort verifying these sites, we retry (up to twice)
  # running the verifier again if we encounter this specific error.

  # Important: On retries, we work with the client-modified page context
  # instead of calling `page.goto(context.url)` again (which would most
  # likely result in another interruptive navigation).
  @puppeteer_wrapper_code """
  export default async function({ page, context }) {
    const MAX_RETRIES = 2

    async function attemptVerification() {
      await page.evaluate(() => {
        #{@verifier_code}
      });

      return await page.evaluate(async (expectedDataDomain, debug) => {
        return await window.verifyPlausibleInstallation(expectedDataDomain, debug);
      }, context.expectedDataDomain, context.debug);
    }

    try {
      await page.setUserAgent(context.userAgent);
      await page.goto(context.url);

      for (let attempt = 0; attempt <= MAX_RETRIES; attempt++) {
        try {
          return await attemptVerification()
        } catch (error) {
          const shouldRetry = typeof error?.message === 'string' && error.message.toLowerCase().includes('execution context')

          if (shouldRetry && attempt <= MAX_RETRIES) {
            // Brief delay before retry
            await new Promise(resolve => setTimeout(resolve, 500))
            continue
          }

          throw error
        }
      }
    } catch (error) {
      const msg = error.message ? error.message : JSON.stringify(error)
      return {data: {completed: false, error: msg}}
    }
  }
  """

  @moduledoc """
  Calls the browserless.io service (local instance can be spawned with `make browserless`)
  and runs verifier script via the [function API](https://docs.browserless.io/HTTP-APIs/function).

  The verification uses a vanilla JS script that runs in the browser context,
  performing a comprehensive Plausible installation verification. Providing
  the following information:

  - `data.snippetsFoundInHead` - plausible snippets found in <head>

  - `data.snippetsFoundInBody` - plausible snippets found in <body>

  - `data.plausibleInstalled` - whether or not the `plausible()` window function was found

  - `data.callbackStatus` - integer. 202 indicates that the server acknowledged the test event.
                            The test event ingestion is discarded based on user-agent, see:
                            `Plausible.InstallationSupport.user_agent/0`

  - `data.dataDomainMismatch` - whether or not script[data-domain] mismatched with site.domain

  - `data.proxyLikely` - whether the script[src] is not a plausible.io URL

  - `data.manualScriptExtension` - whether the site is using script.manual.js

  - `data.unknownAttributes` - whether the script tag has any unknown attributes

  - `data.wordpressPlugin` - whether or not there's a `<meta>` tag with the WP plugin version

  - `data.wordpressLikely` - whether or not the site is built on WordPress

  - `data.gtmLikely` - whether or not the site uses GTM

  - `data.cookieBannerLikely` - whether or not there's a cookie banner blocking Plausible
  """
  use Plausible.InstallationSupport.Check

  @impl true
  def report_progress_as, do: "We're verifying that your visitors are being counted correctly"

  @impl true
  def perform(%State{url: url, data_domain: data_domain} = state) do
    opts = [
      headers: %{content_type: "application/json"},
      body:
        Jason.encode!(%{
          code: @puppeteer_wrapper_code,
          context: %{
            expectedDataDomain: data_domain,
            url: Plausible.InstallationSupport.URL.bust_url(url),
            userAgent: Plausible.InstallationSupport.user_agent(),
            debug: Application.get_env(:plausible, :environment) == "dev"
          }
        }),
      retry: :transient,
      retry_log_level: :warning,
      max_retries: 2
    ]

    extra_opts = Application.get_env(:plausible, __MODULE__)[:req_opts] || []
    opts = Keyword.merge(opts, extra_opts)

    case Req.post(Plausible.InstallationSupport.browserless_function_api_endpoint(), opts) do
      {:ok, %{status: 200, body: %{"data" => %{"completed" => true} = js_data}}} ->
        emit_telemetry_and_log(state.diagnostics, js_data, data_domain)

        put_diagnostics(state,
          plausible_installed?: js_data["plausibleInstalled"],
          callback_status: js_data["callbackStatus"]
        )

      {:ok, %{status: status, body: %{"data" => %{"error" => error}}}} ->
        Logger.warning(
          "[VERIFICATION] Browserless JS error (data_domain='#{data_domain}'): #{inspect(error)}"
        )

        put_diagnostics(state, plausible_installed?: false, service_error: status)

      {:error, %{reason: reason}} ->
        Logger.warning(
          "[VERIFICATION] Browserless request error (data_domain='#{data_domain}'): #{inspect(reason)}"
        )

        put_diagnostics(state, plausible_installed?: false, service_error: reason)
    end
  end

  def telemetry_event(true = _diff), do: [:plausible, :verification, :js_elixir_diff]
  def telemetry_event(false = _diff), do: [:plausible, :verification, :js_elixir_match]

  def emit_telemetry_and_log(elixir_data, js_data, data_domain) do
    diffs =
      for {diff, elixir_diagnostic, js_diagnostic} <- [
            {:data_domain_mismatch_diff, :data_domain_mismatch?, "dataDomainMismatch"},
            {:proxy_likely_diff, :proxy_likely?, "proxyLikely"},
            {:manual_script_extension_diff, :manual_script_extension?, "manualScriptExtension"},
            {:unknown_attributes_diff, :snippet_unknown_attributes?, "unknownAttributes"},
            {:wordpress_plugin_diff, :wordpress_plugin?, "wordpressPlugin"},
            {:wordpress_likely_diff, :wordpress_likely?, "wordpressLikely"},
            {:gtm_likely_diff, :gtm_likely?, "gtmLikely"},
            {:cookie_banner_likely_diff, :cookie_banner_likely?, "cookieBannerLikely"}
          ] do
        case {Map.get(elixir_data, elixir_diagnostic), js_data[js_diagnostic]} do
          {true, false} -> {diff, -1}
          {false, true} -> {diff, 1}
          {_, _} -> {diff, 0}
        end
      end
      |> Map.new()
      |> Map.merge(%{
        snippets_head_diff: js_data["snippetsFoundInHead"] - elixir_data.snippets_found_in_head,
        snippets_body_diff: js_data["snippetsFoundInBody"] - elixir_data.snippets_found_in_body
      })
      |> Map.reject(fn {_k, v} -> v == 0 end)

    any_diff? = map_size(diffs) > 0

    if any_diff? do
      info =
        %{
          domain: data_domain,
          plausible_installed_js: js_data["plausibleInstalled"],
          callback_status_js: js_data["callbackStatus"]
        }
        |> Map.merge(diffs)

      Logger.warning("[VERIFICATION] js_elixir_diff: #{inspect(info)}")
    end

    :telemetry.execute(telemetry_event(any_diff?), %{})
  end
end
