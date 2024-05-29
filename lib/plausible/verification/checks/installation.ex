defmodule Plausible.Verification.Checks.Installation do
  require Logger

  @verification_script_filename "verification/verify_plausible_installed.js"
  @verification_script_path Path.join(:code.priv_dir(:plausible), @verification_script_filename)
  @external_resource @verification_script_path
  @code File.read!(@verification_script_path)

  @moduledoc """
  Calls the browserless.io service (local instance can be spawned with `make browserless`)
  and runs #{@verification_script_filename} via the [function API](https://docs.browserless.io/HTTP-APIs/function).

  The successful execution assumes the following JSON payload:
     - `data.plausibleInstalled` - boolean indicating whether the `plausible()` window function was found
     - `data.callbackStatus` - integer. 202 indicates that the server acknowledged the test event.

  The test event ingestion is discarded based on user-agent, see: `Plausible.Verification.user_agent/0`
  """
  use Plausible.Verification.Check

  @impl true
  def report_progress_as, do: "We're verifying that your visitors are being counted correctly"

  @impl true
  def perform(%State{url: url} = state) do
    opts = [
      headers: %{content_type: "application/json"},
      body:
        Jason.encode!(%{
          code: @code,
          context: %{
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
      {:ok,
       %{
         status: 200,
         body: %{
           "data" =>
             %{"plausibleInstalled" => installed?, "callbackStatus" => callback_status} = data
         }
       }}
      when is_boolean(installed?) ->
        if data["error"] do
          Logger.warning("Browserless error: #{Map.get(data, "error")}")
        end

        put_diagnostics(state, plausible_installed?: installed?, callback_status: callback_status)

      {:ok, %{status: status}} ->
        put_diagnostics(state, plausible_installed?: false, service_error: status)

      {:error, %{reason: reason}} ->
        Logger.warning("Browserless error: #{inspect(reason)}")
        put_diagnostics(state, plausible_installed?: false, service_error: reason)
    end
  end

  defp verification_endpoint() do
    config = Application.fetch_env!(:plausible, __MODULE__)
    token = Keyword.fetch!(config, :token)
    endpoint = Keyword.fetch!(config, :endpoint)
    Path.join(endpoint, "function?token=#{token}&stealth")
  end
end
