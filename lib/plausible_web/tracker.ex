defmodule PlausibleWeb.Tracker do
  @moduledoc """
  Helper module for building the dynamic tracker script. Used by PlausibleWeb.TrackerPlug.
  """

  @external_resource "priv/tracker/js/plausible-main.js"
  @plausible_main_script Application.app_dir(:plausible, "priv/tracker/js/plausible-main.js")
                         |> File.read!()

  def plausible_main_script_tag(site) do
    config_js_content =
      site
      |> plausible_main_config()
      |> Enum.map(fn
        {key, value} when is_binary(value) -> "#{key}:#{Jason.encode!(value)}"
        # :TRICKY: Save bytes by using short-hand for true
        {key, true} -> "#{key}:!0"
        # Not enabled values can be omitted
        {_key, false} -> nil
      end)
      |> Enum.reject(&(&1 == nil))
      |> Enum.sort_by(&String.length/1, :desc)
      |> Enum.join(",")

    @plausible_main_script
    |> String.replace("\"<%= @config_json %>\"", "{#{config_js_content}}")
  end

  def plausible_main_config(site) do
    script_config = site.installation_meta.script_config

    %{
      domain: site.domain,
      endpoint: "#{PlausibleWeb.Endpoint.url()}/api/event",
      hash: Map.get(script_config, "hash", false),
      outboundLinks: Map.get(script_config, "outbound-links", false),
      fileDownloads: Map.get(script_config, "file-downloads", false),
      pageviewProps: Map.get(script_config, "pageview-props", false),
      taggedEvents: Map.get(script_config, "tagged-events", false),
      revenue: Map.get(script_config, "revenue", false),
      # Options not directly exposed via onboarding
      local: false,
      manual: false
    }
  end
end
