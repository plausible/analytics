defmodule Plausible.InstallationSupport.Checks.Detection do
  @moduledoc """
  Calls the browserless.io service (local instance can be spawned with `make browserless`)
  and runs verifier script via the [function API](https://docs.browserless.io/HTTP-APIs/function).

  * v1_detected (optional - detection can take up to @plausible_window_check_timeout_ms)
  * gtm_likely
  * wordpress_likely
  * wordpress_plugin

  These diagnostics are used to determine what installation type to recommend,
  and whether to provide a notice for upgrading an existing v1 integration to v2.
  """

  require Logger
  use Plausible.InstallationSupport.Check
  alias Plausible.InstallationSupport.BrowserlessConfig

  @detector_code_path "priv/tracker/installation_support/detector.js"
  @external_resource @detector_code_path

  # On CI, the file might not be present for static checks so we default to empty string
  @detector_code (case File.read(Application.app_dir(:plausible, @detector_code_path)) do
                    {:ok, content} -> content
                    {:error, _} -> ""
                  end)

  # Puppeteer wrapper function that executes the vanilla JS verifier code
  @puppeteer_wrapper_code """
  export default async function({ page, context: { url, userAgent, ...functionContext } }) {
    try {
      await page.setUserAgent(userAgent);
      await page.goto(url);

      await page.evaluate(() => {
        #{@detector_code} // injects window.scanPageBeforePlausibleInstallation
      });

      return await page.evaluate(
        (c) => window.scanPageBeforePlausibleInstallation(c),
        { ...functionContext }
      );
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

  # We define a timeout for the browserless endpoint call to avoid waiting too long for a response
  @endpoint_timeout_ms 2_000

  # This timeout determines how long we wait for window.plausible to be initialized on the page, used for detecting whether v1 installed
  @plausible_window_check_timeout_ms 1_500

  # To support browserless API being unavailable or overloaded, we retry the endpoint call if it doesn't return a successful response
  @max_retries 1

  @impl true
  def report_progress_as, do: "We're checking your site to recommend the best installation method"

  @impl true
  def perform(%State{url: url, assigns: %{detect_v1?: detect_v1?}} = state) do
    opts =
      [
        headers: %{content_type: "application/json"},
        body:
          Jason.encode!(%{
            code: @puppeteer_wrapper_code,
            context: %{
              url: url,
              userAgent: Plausible.InstallationSupport.user_agent(),
              detectV1: detect_v1?,
              timeoutMs: @plausible_window_check_timeout_ms,
              debug: Application.get_env(:plausible, :environment) == "dev"
            }
          }),
        params: %{timeout: @endpoint_timeout_ms},
        retry: &BrowserlessConfig.retry_browserless_request/2,
        retry_log_level: :warning,
        max_retries: @max_retries
      ]
      |> Keyword.merge(Application.get_env(:plausible, __MODULE__)[:req_opts] || [])

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
    "[DETECTION] #{message} (data_domain='#{state.data_domain}')"
  end

  defp parse_to_diagnostics(data),
    do: [
      v1_detected: data["v1Detected"],
      gtm_likely: data["gtmLikely"],
      wordpress_likely: data["wordpressLikely"],
      wordpress_plugin: data["wordpressPlugin"],
      service_error: nil
    ]
end
