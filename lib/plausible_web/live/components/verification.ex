defmodule PlausibleWeb.Live.Components.Verification do
  @moduledoc """
  This component is responsible for rendering the verification progress
  and diagnostics.
  """
  use Phoenix.LiveComponent
  use Plausible

  alias PlausibleWeb.Router.Helpers, as: Routes

  import PlausibleWeb.Components.Generic

  attr :domain, :string, required: true

  attr :message, :string, default: "We're visiting your site to ensure that everything is working"

  attr :finished?, :boolean, default: false
  attr :success?, :boolean, default: false
  attr :interpretation, Plausible.Verification.Diagnostics.Result, default: nil
  attr :attempts, :integer, default: 0
  attr :flow, :string, default: ""
  attr :installation_type, :string, default: nil
  attr :awaiting_first_pageview?, :boolean, default: false

  def render(assigns) do
    ~H"""
    <div id="progress-indicator">
      <PlausibleWeb.Components.Generic.focus_box>
        <div
          :if={not @finished?}
          class="mx-auto flex h-12 w-12 items-center justify-center rounded-full bg-green-100 dark:bg-gray-700"
        >
          <div class="block pulsating-circle"></div>
        </div>

        <div
          :if={@finished? and @success?}
          class="mx-auto flex h-12 w-12 items-center justify-center rounded-full bg-green-100 dark:bg-green-500"
          id="check-circle"
        >
          <Heroicons.check_badge class="h-6 w-6 text-green-600 bg-green-100 dark:bg-green-500 dark:text-green-200" />
        </div>

        <div
          :if={@finished? and not @success?}
          class="mx-auto flex h-12 w-12 items-center justify-center rounded-full bg-red-100 dark:bg-red-200"
          id="error-circle"
        >
          <Heroicons.exclamation_triangle class="h-6 w-6 text-red-600 bg-red-100 dark:bg-red-200 dark:text-red-800" />
        </div>

        <div class="mt-6">
          <h3 class="font-semibold leading-6 text-xl">
            <span :if={@finished? and @success?}>Success!</span>
            <span :if={not @finished?}>Verifying your installation</span>

            <span :if={@finished? and not @success? and @interpretation}>
              <%= List.first(@interpretation.errors) %>
            </span>
          </h3>
          <p :if={@finished? and @success?} id="progress" class="mt-2">
            Your integration is working and visitors are being counted accurately
          </p>
          <p
            :if={@finished? and @success? and @awaiting_first_pageview?}
            id="progress"
            class="mt-2 animate-pulse"
          >
            Your integration is working. Awaiting your first pageview.
          </p>
          <p :if={not @finished?} class="mt-2 animate-pulse" id="progress"><%= @message %></p>

          <p
            :if={@finished? and not @success? and @interpretation}
            class="mt-2 text-ellipsis overflow-hidden"
            id="recommendation"
          >
            <span><%= List.first(@interpretation.recommendations).text %>.&nbsp;</span>
            <.styled_link href={List.first(@interpretation.recommendations).url} new_tab={true}>
              Learn more
            </.styled_link>
          </p>
        </div>

        <div :if={@finished?} class="mt-8">
          <.button_link :if={not @success?} href="#" phx-click="retry" class="w-full">
            Verify installation again
          </.button_link>
          <.button_link
            :if={@success?}
            href={"/#{URI.encode_www_form(@domain)}?skip_to_dashboard=true"}
            class="w-full font-bold mb-4"
          >
            Go to the dashboard
          </.button_link>
        </div>

        <:footer :if={@finished? and not @success?}>
          <ol class="list-disc space-y-1 ml-4 mt-1 mb-4">
            <%= if ee?() and @finished? and not @success? and @attempts >= 3 do %>
              <li>
                <b>Need further help with your integration?</b>
                <.styled_link href="https://plausible.io/contact">
                  Contact us
                </.styled_link>
              </li>
            <% end %>
            <li>
              Need to see installation instructions again?
              <.styled_link href={
                Routes.site_path(PlausibleWeb.Endpoint, :installation, @domain,
                  flow: @flow,
                  installation_type: @installation_type
                )
              }>
                Click here
              </.styled_link>
            </li>
            <li>
              Run verification later and go to Site Settings?
              <.styled_link href={"/#{URI.encode_www_form(@domain)}/settings/general"}>
                Click here
              </.styled_link>
            </li>
          </ol>
        </:footer>
      </PlausibleWeb.Components.Generic.focus_box>
    </div>
    """
  end
end
