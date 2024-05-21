defmodule Plausible.Verification.Checks.ScanBody do
  @moduledoc """
  Naive way of detecting GTM and WordPress powered sites.
  """
  use Plausible.Verification.Check

  @impl true
  def friendly_name, do: "We're visiting your site to ensure that everything is working correctly"

  @impl true
  def perform(%State{assigns: %{raw_body: body}} = state) when is_binary(body) do
    state
    |> scan_gtm()
    |> scan_wp()
  end

  def perform(state), do: state

  @gtm_signatures [
    "gtm.js",
    "googletagmanager.com"
  ]

  defp scan_gtm(state) do
    if Enum.any?(@gtm_signatures, &String.contains?(state.assigns.raw_body, &1)) do
      put_diagnostics(state, gtm_likely?: true)
    else
      state
    end
  end

  @wordpress_signatures [
    "wp-content",
    "wp-includes",
    "wp-json"
  ]

  defp scan_wp(state) do
    if Enum.any?(@wordpress_signatures, &String.contains?(state.assigns.raw_body, &1)) do
      put_diagnostics(state, wordpress_likely?: true)
    else
      state
    end
  end
end
