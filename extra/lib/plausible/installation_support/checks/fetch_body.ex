defmodule Plausible.InstallationSupport.Checks.FetchBody do
  @moduledoc """
  Fetches the body of the site and extracts the HTML document, if available, for
  further processing. See `Plausible.InstallationSupport.LegacyVerification.Checks`
  for the execution sequence.
  """
  use Plausible.InstallationSupport.Check

  @impl true
  def report_progress_as, do: "We're visiting your site to ensure that everything is working"

  @impl true

  def perform(%State{url: "https://" <> _ = url} = state) do
    fetch_body_opts = Application.get_env(:plausible, __MODULE__)[:req_opts] || []

    opts =
      Keyword.merge(
        [
          base_url: url,
          max_redirects: 4,
          max_retries: 3,
          retry_log_level: :warning
        ],
        fetch_body_opts
      )

    {req, resp} = opts |> Req.new() |> Req.Request.run_request()

    case resp do
      %Req.Response{body: body}
      when is_binary(body) ->
        state
        |> assign(final_domain: req.url.host)
        |> extract_document(resp)

      _ ->
        state
    end
  end

  defp extract_document(state, response) do
    with true <- html?(response),
         {:ok, document} <- Floki.parse_document(response.body) do
      state
      |> assign(raw_body: response.body, document: document, headers: response.headers)
      |> put_diagnostics(body_fetched?: true)
    else
      _ ->
        state
    end
  end

  defp html?(%Req.Response{headers: headers}) do
    headers
    |> Map.get("content-type", "")
    |> List.wrap()
    |> List.first()
    |> String.contains?("text/html")
  end
end
