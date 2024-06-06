defmodule Plausible.Verification.Checks.ScanBody do
  @moduledoc """
  Naive way of detecting GTM and WordPress powered sites.
  """
  use Plausible.Verification.Check

  @impl true
  def report_progress_as, do: "We're visiting your site to ensure that everything is working"

  @impl true
  def perform(%State{assigns: %{raw_body: body}} = state) when is_binary(body) do
    state
    |> scan_wp_plugin()
    |> scan_gtm()
    |> scan_wp()
    |> scan_cookie_banners()
  end

  def perform(state), do: state

  defp scan_wp_plugin(%{assigns: %{document: document}} = state) do
    case Floki.find(document, ~s|meta[name="plausible-analytics-version"]|) do
      [] ->
        state

      [_] ->
        state
        |> assign(skip_wordpress_check: true)
        |> put_diagnostics(wordpress_likely?: true, wordpress_plugin?: true)
    end
  end

  defp scan_wp_plugin(state) do
    state
  end

  @gtm_signatures [
    "googletagmanager.com/gtm.js"
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

  defp scan_wp(%{assigns: %{skip_wordpress_check: true}} = state) do
    state
  end

  defp scan_wp(state) do
    if Enum.any?(@wordpress_signatures, &String.contains?(state.assigns.raw_body, &1)) do
      put_diagnostics(state, wordpress_likely?: true)
    else
      state
    end
  end

  defp scan_cookie_banners(%{assigns: %{raw_body: body}} = state) do
    # We'll start with CookieBot. Not using the selectors yet, as seen at
    # https://github.com/cavi-au/Consent-O-Matic/blob/master/rules/cookiebot.json
    # because those don't seem to be appearing without JS evaluation. 
    # If this ever becomes an issue, we'll have to move that check to headless.
    if String.contains?(body, "cookiebot") do
      put_diagnostics(state, cookie_banner_likely?: true)
    else
      state
    end
  end

  defp scan_cookie_banners(state) do
    state
  end
end
