defmodule PlausibleWeb.Components.Site.SettingsLookerStudio do
  use PlausibleWeb, :component
  use Plausible

  on_ee do
    def render(assigns) do
      ~H"""
      <.tile docs="looker-studio">
        <:title>
          Google Looker Studio Connector
        </:title>
        <:subtitle>
          <p>
            You can use our Looker Studio connector to build custom reports with your Plausible data.
          </p>
        </:subtitle>

        <div class="mt-4 text-sm">
          Plausible Looker Studio Connector adds powerful reporting features that help turn Plausible
          into an even better replacement for Google Analytics.
          <.styled_link href="https://plausible.io/docs/looker-studio" new_tab={true}>
            Read the docs
          </.styled_link>
        </div>
      </.tile>
      """
    end
  else
    def render(assigns), do: ~H""
  end
end
