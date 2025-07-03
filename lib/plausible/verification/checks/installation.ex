defmodule Plausible.Verification.Checks.Installation do
  require Logger

  path = Application.app_dir(:plausible, "priv/tracker/verifier/verifier-v1.js")
  # On CI, the file might not be present for static checks so we create an empty one
  File.touch!(path)

  @verifier_code File.read!(path)
  @external_resource "priv/tracker/verifier/verifier-v1.js"

  # Puppeteer wrapper function that executes the vanilla JS verifier code
  @puppeteer_wrapper_code """
  export default async function({ page, context }) {
    try {
      await page.setUserAgent(context.userAgent);
      await page.goto(context.url);

      await page.evaluate(() => {
        #{@verifier_code}
      });

      return await page.evaluate(async (expectedDataDomain, debug) => {
        return await window.verifyPlausibleInstallation(expectedDataDomain, debug);
      }, context.expectedDataDomain, context.debug);
    } catch (error) {
      return {data: {completed: false, error: error}}
    }
  }
  """

  @moduledoc """
  Calls the browserless.io service (local instance can be spawned with `make browserless`)
  and runs #{@verifier_script_filename} via the [function API](https://docs.browserless.io/HTTP-APIs/function).

  The verification uses a vanilla JS script that runs in the browser context,
  performing a comprehensive Plausible installation verification. Providing
  the following information:

  - `data.snippetsFoundInHead` - plausible snippets found in <head>
  - `data.snippetsFoundInBody` - plausible snippets found in <body>
  - `data.dataDomainMismatch` - whether or not script[data-domain] mismatched with site.domain
  - `data.plausibleInstalled` - boolean indicating whether the `plausible()` window function was found
  - `data.callbackStatus` - integer. 202 indicates that the server acknowledged the test event.

  The test event ingestion is discarded based on user-agent, see: `Plausible.Verification.user_agent/0`
  """
  use Plausible.Verification.Check

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
            url: Plausible.Verification.URL.bust_url(url),
            userAgent: Plausible.Verification.user_agent(),
            debug: Application.get_env(:plausible, :environment) == "dev"
          }
        }),
      retry: :transient,
      retry_log_level: :warning,
      max_retries: 2
    ]

    extra_opts = Application.get_env(:plausible, __MODULE__)[:req_opts] || []
    opts = Keyword.merge(opts, extra_opts)

    case Req.post(verification_endpoint(), opts) do
      {:ok, %{status: 200, body: %{"data" => %{"completed" => true} = js_data}}} ->
        emit_telemetry(state.diagnostics, js_data)

        snippets_head =
          [js_data["snippetsFoundInHead"], state.diagnostics.snippets_found_in_head]
          |> Enum.max()

        snippets_body =
          [js_data["snippetsFoundInBody"], state.diagnostics.snippets_found_in_body]
          |> Enum.max()

        put_diagnostics(state,
          snippets_found_in_head: snippets_head,
          snippets_found_in_body: snippets_body,
          plausible_installed?: js_data["plausibleInstalled"],
          callback_status: js_data["callbackStatus"]
        )

      {:ok, %{status: status, body: %{"data" => %{"error" => error}}}} ->
        Logger.warning("Browserless error: #{inspect(error)}")
        put_diagnostics(state, plausible_installed?: false, service_error: status)

      {:error, %{reason: reason}} ->
        Logger.warning("Browserless error: #{inspect(reason)}")
        put_diagnostics(state, plausible_installed?: false, service_error: reason)
    end
  end

  @doc """
  In the future, the plan is to move most checks to the client side.
  # But for now, to be safe, we are still relying on checks carried out in
  # Elixir while sending telemetry events to find out possible differences.
  """
  def telemetry_event(), do: [:plausible, :verification, :v1]

  defp emit_telemetry(existing_elixir_diagnostics, js_data) do
    %{
      snippets_found_in_head: snippets_found_in_head_elixir,
      snippets_found_in_body: snippets_found_in_body_elixir,
      data_domain_mismatch?: data_domain_mismatch_elixir
    } = existing_elixir_diagnostics

    %{
      "snippetsFoundInHead" => snippets_found_in_head_js,
      "snippetsFoundInBody" => snippets_found_in_body_js,
      "dataDomainMismatch" => data_domain_mismatch_js,
      "callbackStatus" => callback_status_js,
      "plausibleInstalled" => plausible_installed_js
    } = js_data

    snippets_head_diff = snippets_found_in_head_js - snippets_found_in_head_elixir
    snippets_body_diff = snippets_found_in_body_js - snippets_found_in_body_elixir

    data_domain_mismatch_diff =
      case {data_domain_mismatch_js, data_domain_mismatch_elixir} do
        {true, false} -> 1
        {false, true} -> -1
        {_, _} -> 0
      end

    any_diff? =
      [snippets_head_diff, snippets_body_diff, data_domain_mismatch_diff]
      |> Enum.any?(&(&1 != 0))

    telemetry_metadata = %{
      plausible_installed_js: plausible_installed_js,
      callback_status_js: callback_status_js,
      any_diff: any_diff?,
      snippets_head_diff: snippets_head_diff,
      snippets_body_diff: snippets_body_diff,
      data_domain_mismatch_diff: data_domain_mismatch_diff
    }

    :telemetry.execute(telemetry_event(), %{}, telemetry_metadata)
  end

  defp verification_endpoint() do
    config = Application.fetch_env!(:plausible, __MODULE__)
    token = Keyword.fetch!(config, :token)
    endpoint = Keyword.fetch!(config, :endpoint)
    Path.join(endpoint, "function?token=#{token}&stealth")
  end
end
