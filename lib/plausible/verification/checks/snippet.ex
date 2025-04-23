defmodule Plausible.Verification.Checks.Snippet do
  @moduledoc """
  The check looks for Plausible snippets and tries to address the common
  integration issues, such as bad placement, data-domain typos, unknown 
  attributes frequently added by performance optimization plugins, etc.
  """
  use Plausible.Verification.Check

  @impl true
  def report_progress_as, do: "We're looking for the Plausible snippet on your site"

  @impl true
  def perform(%State{assigns: %{document: document}} = state) do
    IO.inspect(document, label: :doc)
    in_head = Floki.find(document, "head script[data-domain][src]")
    in_body = Floki.find(document, "body script[data-domain][src]")

    all = in_head ++ in_body

    put_diagnostics(state,
      snippets_found_in_head: Enum.count(in_head),
      snippets_found_in_body: Enum.count(in_body),
      proxy_likely?: proxy_likely?(all),
      manual_script_extension?: manual_script_extension?(all),
      snippet_unknown_attributes?: unknown_attributes?(all),
      data_domain_mismatch?:
        data_domain_mismatch?(all, state.data_domain, state.assigns[:final_domain])
    )
  end

  def perform(state), do: state

  defp manual_script_extension?(nodes) do
    nodes
    |> Floki.attribute("src")
    |> Enum.any?(&String.contains?(&1, "manual."))
  end

  defp proxy_likely?(nodes) do
    nodes
    |> Floki.attribute("src")
    |> Enum.any?(&(not String.starts_with?(&1, PlausibleWeb.Endpoint.url())))
  end

  @known_attributes [
    "data-domain",
    "src",
    "defer",
    "data-api",
    "data-exclude",
    "data-include",
    "data-cfasync"
  ]

  defp unknown_attributes?(nodes) do
    Enum.any?(nodes, fn {_, attrs, _} ->
      Enum.any?(attrs, fn
        {"type", "text/javascript"} ->
          false

        {"event-" <> _, _} ->
          false

        {key, _} ->
          key not in @known_attributes
      end)
    end)
  end

  defp data_domain_mismatch?(nodes, data_domain, final_data_domain) do
    nodes
    |> Floki.attribute("data-domain")
    |> Enum.any?(fn script_data_domain ->
      multiple = String.split(script_data_domain, ",")

      data_domain not in multiple and final_data_domain not in multiple
    end)
  end
end
