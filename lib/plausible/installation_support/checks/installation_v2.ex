defmodule Plausible.InstallationSupport.Checks.InstallationV2 do
  require Logger

  path = Application.app_dir(:plausible, "priv/tracker/installation_support/verifier-v2.js")
  # On CI, the file might not be present for static checks so we create an empty one
  File.touch!(path)

  @verifier_code File.read!(path)
  @external_resource "priv/tracker/installation_support/verifier-v2.js"

  @function_check_timeout 10_000

  # Puppeteer wrapper function that executes the vanilla JS verifier code
  @puppeteer_wrapper_code """
  export default async function({ page, context }) {
    try {
      await page.setUserAgent(context.userAgent);
      const response = await page.goto(context.url);

      await page.evaluate(() => {
        #{@verifier_code}
      });

      return await page.evaluate(async ({ responseHeaders, debug, timeoutMs, cspHostsToCheck }) => {
        return await window.verifyPlausibleInstallation({ responseHeaders, debug, timeoutMs, cspHostsToCheck });
      }, {
        timeoutMs: context.timeoutMs,
        responseHeaders: response.headers(),
        debug: context.debug,
        cspHostsToCheck: context.cspHostsToCheck
      });
    } catch (error) {
      return {
        data: {
          completed: false,
          error: {
            message: error?.message ?? JSON.stringify(error),
          }
        }
      }
    }
  }
  """

  @moduledoc """
  Calls the browserless.io service (local instance can be spawned with `make browserless`)
  and runs verifier script via the [function API](https://docs.browserless.io/HTTP-APIs/function).
  """
  use Plausible.InstallationSupport.Check

  @impl true
  def report_progress_as, do: "We're verifying that your visitors are being counted correctly"

  @impl true
  def perform(%State{url: url} = state) do
    opts = [
      headers: %{content_type: "application/json"},
      body:
        JSON.encode!(%{
          code: @puppeteer_wrapper_code,
          context: %{
            cspHostsToCheck: [PlausibleWeb.Endpoint.host()],
            timeoutMs: @function_check_timeout,
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
      {:ok, %{body: body, status: status}} ->
        handle_browserless_response(state, body, status)

      {:error, %{reason: reason}} ->
        Logger.warning(warning_message("Browserless request error: #{inspect(reason)}", state))

        put_diagnostics(state, service_error: reason)
    end
  end

  defp handle_browserless_response(
         state,
         %{"data" => %{"completed" => completed} = data},
         _status
       ) do
    if completed do
      put_diagnostics(
        state,
        disallowed_by_csp: data["disallowedByCsp"],
        plausible_is_on_window: data["plausibleIsOnWindow"],
        plausible_is_initialized: data["plausibleIsInitialized"],
        plausible_version: data["plausibleVersion"],
        plausible_variant: data["plausibleVariant"],
        test_event: data["testEvent"],
        cookie_banner_likely: data["cookieBannerLikely"],
        service_error: nil
      )
    else
      Logger.warning(
        warning_message(
          "Browserless function returned with completed: false, error.message: #{inspect(data["error"]["message"])}",
          state
        )
      )

      put_diagnostics(state, service_error: data["error"]["message"])
    end
  end

  defp handle_browserless_response(state, _body, status) do
    error = "Unhandled browserless response with status: #{status}"
    Logger.warning(warning_message(error, state))

    put_diagnostics(state, service_error: error)
  end

  defp warning_message(message, state) do
    "[VERIFICATION v2] #{message} (data_domain='#{state.data_domain}')"
  end
end
