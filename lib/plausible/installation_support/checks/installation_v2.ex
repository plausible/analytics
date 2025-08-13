defmodule Plausible.InstallationSupport.Checks.InstallationV2 do
  @moduledoc """
  Calls the browserless.io service (local instance can be spawned with `make browserless`)
  and runs verifier script via the [function API](https://docs.browserless.io/HTTP-APIs/function).
  """

  require Logger
  use Plausible.InstallationSupport.Check
  alias Plausible.InstallationSupport.BrowserlessConfig

  @verifier_code_path "priv/tracker/installation_support/verifier-v2.js"
  @external_resource @verifier_code_path

  # On CI, the file might not be present for static checks so we default to empty string
  @verifier_code (case File.read(Application.app_dir(:plausible, @verifier_code_path)) do
                    {:ok, content} -> content
                    {:error, _} -> ""
                  end)

  # Puppeteer wrapper function that executes the vanilla JS verifier code
  @puppeteer_wrapper_code """
  export default async function({ page, context: { url, userAgent, maxAttempts, timeoutBetweenAttemptsMs, ...functionContext } }) {
    try {
      await page.setUserAgent(userAgent)
      const response = await page.goto(url)
      const responseHeaders = response.headers()

      async function verify() {
        await page.evaluate(() => {#{@verifier_code}}) // injects window.verifyPlausibleInstallation
        return await page.evaluate(
          (c) => window.verifyPlausibleInstallation(c),
          { ...functionContext, responseHeaders }
        );
      }

      let lastError;
      for (let attempts = 1; attempts <= maxAttempts; attempts++) {
        try {
          const output = await verify();
          return {
            data: {
              ...output.data,
              attempts
            },
          };
        } catch (error) {
          lastError = error;
          if (
            typeof error?.message === "string" &&
            error.message.toLowerCase().includes("execution context")
          ) {
            await new Promise((resolve) => setTimeout(resolve, timeoutBetweenAttemptsMs));
            continue;
          }
          throw error
        }
      }
      throw lastError;
    } catch (error) {
      return {
        data: {
          completed: false,
          error: {
            message: error?.message ?? JSON.stringify(error)
          }
        }
      }
    }
  }
  """

  # To support browserless API being unavailable or overloaded, we retry the endpoint call if it doesn't return a successful response
  @max_retries 1

  # We define a timeout for the browserless endpoint call to avoid waiting too long for a response
  @endpoint_timeout_ms 10_000

  # This timeout determines how long we wait for window.plausible to be initialized on the page, including sending the test event
  @plausible_window_check_timeout_ms 4_000

  # To handle navigation that happens immediately on the page, we attempt to verify the installation multiple times _within a single browserless endpoint call_
  @max_attempts 2
  @timeout_between_attempts_ms 500

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
            maxAttempts: @max_attempts,
            timeoutMs: @plausible_window_check_timeout_ms,
            timeoutBetweenAttemptsMs: @timeout_between_attempts_ms,
            cspHostToCheck: PlausibleWeb.Endpoint.host(),
            url: Plausible.InstallationSupport.URL.bust_url(url),
            userAgent: Plausible.InstallationSupport.user_agent(),
            debug: Application.get_env(:plausible, :environment) == "dev"
          }
        }),
      params: %{timeout: @endpoint_timeout_ms},
      retry: &BrowserlessConfig.retry_browserless_request/2,
      retry_log_level: :warning,
      max_retries: @max_retries
    ]

    extra_opts = Application.get_env(:plausible, __MODULE__)[:req_opts] || []
    opts = Keyword.merge(opts, extra_opts)

    case Req.post(BrowserlessConfig.browserless_function_api_endpoint(), opts) do
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
        parse_to_diagnostics(data)
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

  defp parse_to_diagnostics(data),
    do: [
      disallowed_by_csp: data["disallowedByCsp"],
      plausible_is_on_window: data["plausibleIsOnWindow"],
      plausible_is_initialized: data["plausibleIsInitialized"],
      plausible_version: data["plausibleVersion"],
      plausible_variant: data["plausibleVariant"],
      test_event: data["testEvent"],
      cookie_banner_likely: data["cookieBannerLikely"],
      attempts: data["attempts"],
      service_error: nil
    ]
end
