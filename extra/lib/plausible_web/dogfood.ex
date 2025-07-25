defmodule PlausibleWeb.Dogfood do
  @moduledoc """
  Plausible tracking itself functions
  """

  def script_params(assigns) do
    %{
      script_url: script_url(assigns),
      domain_to_replace: domain_to_replace(assigns),
      location_override: location_override(assigns),
      custom_properties: custom_properties(assigns),
      capture_on_localhost: Application.get_env(:plausible, :environment) == "dev"
    }
  end

  defp script_url(assigns) do
    env = Application.get_env(:plausible, :environment)
    selfhost? = Application.get_env(:plausible, :is_selfhost)

    tracker_script_config_id =
      cond do
        env == "prod" and selfhost? ->
          "V5OUguy5m04s95qHnmGbH"

        env == "prod" and assigns[:embedded] ->
          "Qo3A7Ksnbn-wYQWMijuR3"

        env == "prod" ->
          "6_srOGVV9SLMWJ1ZpUAbG"

        env == "staging" ->
          "egYOCIzzYzPL9v6GHLc-7"

        env in ["dev", "ce_dev"] ->
          # By default we're not letting the app track itself on localhost.
          # The requested script will be `t/.js` and it will respond with 404.
          # If you wish to track the app itself, uncomment the following line
          # and replace the site_id if necessary (1 stands for dummy.site).

          # PlausibleWeb.Tracker.get_or_create_tracker_script_configuration!(1).id
          ""

        env in ["test", "ce_test"] ->
          ""
      end

    "#{PlausibleWeb.Endpoint.url()}/t/#{tracker_script_config_id}.js"
  end

  # TRICKY: The React dashboard uses history-based SPA navigation
  # which triggers pageviews on routes that the backend is unaware
  # of (e.g.`/:domain/pages`). As opposed to other site paths like
  # `/:domain/settings/general` we cannot override the entire URL.
  # To still make sure we're not capturing customer domains we run
  # a string replace in `payload.u`.
  defp domain_to_replace(assigns) do
    if not is_nil(assigns[:site]) and assigns[:demo] != true do
      URI.encode_www_form(assigns.site.domain)
    end
  end

  defp location_override(%{dogfood_page_path: path}) when is_binary(path) do
    Path.join(PlausibleWeb.Endpoint.url(), path)
  end

  defp location_override(_), do: nil

  defp custom_properties(%{current_user: user}) when is_map(user) do
    %{logged_in: true, theme: user.theme}
  end

  defp custom_properties(_) do
    %{logged_in: false}
  end
end
