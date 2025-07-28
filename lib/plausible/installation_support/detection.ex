defmodule Plausible.InstallationSupport.Detection do
  @moduledoc """
  Exposes a perform function which visits the given URL via a Browserless
  /function API call, and in a returns the following diagnostics:

  * v1_detected (optional - detection can take up to 3s)
  * gtm_likely
  * wordpress_likely
  * wordpress_plugin

  These diagnostics are used to determine what installation type to recommend,
  and whether to provide a notice for upgrading an existing v1 integration to v2.
  """
  require Logger
  alias Plausible.InstallationSupport

  @external_resource "priv/tracker/installation_support/detector.js"

  # On CI, the file might not be present for static checks so we default to empty string
  @detector_code (case File.read(Application.app_dir(:plausible, @external_resource)) do
                    {:ok, content} -> content
                    {:error, _} -> ""
                  end)

  # Puppeteer wrapper function that executes the vanilla JS verifier code
  @puppeteer_wrapper_code """
  export default async function({ page, context }) {
    try {
      await page.setUserAgent(context.userAgent);
      await page.goto(context.url);

      await page.evaluate(() => {
        #{@detector_code}
      });

      return await page.evaluate(async (detectV1, debug) => {
        return await window.scanPageBeforePlausibleInstallation(detectV1, debug);
      }, context.detectV1, context.debug);
    } catch (error) {
      const msg = error.message ? error.message : JSON.stringify(error)
      return {data: {completed: false, error: msg}}
    }
  }
  """

  def perform(url, opts \\ []) do
    req_opts =
      [
        headers: %{content_type: "application/json"},
        body:
          Jason.encode!(%{
            code: @puppeteer_wrapper_code,
            context: %{
              url: url,
              userAgent: InstallationSupport.user_agent(),
              detectV1: Keyword.get(opts, :detect_v1?, false),
              debug: Application.get_env(:plausible, :environment) == "dev"
            }
          }),
        retry: :transient,
        retry_log_level: :warning,
        max_retries: 2
      ]
      |> Keyword.merge(Application.get_env(:plausible, __MODULE__)[:req_opts] || [])

    case Req.post(InstallationSupport.browserless_function_api_endpoint(), req_opts) do
      {:ok, %{status: 200, body: %{"data" => %{"completed" => true} = js_data}}} ->
        {:ok,
         %{
           v1_detected: js_data["v1Detected"],
           gtm_likely: js_data["gtmLikely"],
           wordpress_likely: js_data["wordpressLikely"],
           wordpress_plugin: js_data["wordpressPlugin"]
         }}

      {:ok, %{body: %{"data" => %{"error" => error}}}} ->
        Logger.warning("[DETECTION] Browserless JS error (url='#{url}'): #{inspect(error)}")

        {:error, {:browserless, error}}

      {:error, %{reason: reason}} ->
        Logger.warning("[DETECTION] Browserless request error (url='#{url}'): #{inspect(reason)}")

        {:error, {:req, reason}}
    end
  end
end
