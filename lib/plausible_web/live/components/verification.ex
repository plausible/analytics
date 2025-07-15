defmodule PlausibleWeb.Live.Components.Verification do
  @moduledoc """
  This component is responsible for rendering the verification progress
  and diagnostics.
  """
  use Phoenix.LiveComponent
  use Plausible

  alias PlausibleWeb.Router.Helpers, as: Routes
  alias Plausible.InstallationSupport.{State, LegacyVerification}

  import PlausibleWeb.Components.Generic

  attr(:domain, :string, required: true)

  attr(:message, :string,
    default: "We're visiting your site to ensure that everything is working"
  )

  attr(:super_admin?, :boolean, default: false)
  attr(:finished?, :boolean, default: false)
  attr(:success?, :boolean, default: false)
  attr(:verification_state, State, default: nil)
  attr(:interpretation, LegacyVerification.Diagnostics.Result, default: nil)
  attr(:attempts, :integer, default: 0)
  attr(:flow, :string, default: "")
  attr(:installation_type, :string, default: nil)
  attr(:awaiting_first_pageview?, :boolean, default: false)

  def render(assigns) do
    ~H"""
    <div id="progress-indicator">
      <.focus_box>
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

        <div class="mt-8">
          <.title>
            <span :if={@finished? and @success?}>Success!</span>
            <span :if={not @finished?}>Verifying your installation</span>

            <span :if={@finished? and not @success? and @interpretation}>
              {List.first(@interpretation.errors)}
            </span>
          </.title>
          <p :if={@finished? and @success?} id="progress" class="text-sm mt-4">
            Your installation is working and visitors are being counted accurately
          </p>
          <p
            :if={@finished? and @success? and @awaiting_first_pageview?}
            id="awaiting"
            class="text-sm mt-4 animate-pulse"
          >
            Awaiting your first pageview
          </p>
          <p :if={not @finished?} class="text-sm mt-4 animate-pulse" id="progress">{@message}</p>

          <p
            :if={@finished? and not @success? and @interpretation}
            class="mt-4 text-sm text-ellipsis overflow-hidden"
            id="recommendation"
          >
            <span>{List.first(@interpretation.recommendations).text}.&nbsp;</span>
            <.styled_link href={List.first(@interpretation.recommendations).url} new_tab={true}>
              Learn more
            </.styled_link>
          </p>
        </div>

        <div :if={@finished?} class="mt-6">
          <.button_link :if={not @success?} mt?={false} href="#" phx-click="retry" class="w-full">
            Verify installation again
          </.button_link>
          <.button_link
            :if={@success?}
            mt?={false}
            href={"/#{URI.encode_www_form(@domain)}?skip_to_dashboard=true"}
            class="w-full font-bold mb-4"
          >
            Go to the dashboard
          </.button_link>
        </div>

        <:footer :if={@finished? and not @success?}>
          <.focus_list>
            <:item :if={ee?() and @attempts >= 3}>
              <b>Need further help with your installation?</b>
              <.styled_link href="https://plausible.io/contact">
                Contact us
              </.styled_link>
            </:item>
            <:item>
              Need to see installation instructions again?
              <.styled_link href={
                Routes.site_path(PlausibleWeb.Endpoint, :installation, @domain,
                  flow: @flow,
                  installation_type: @installation_type
                )
              }>
                Click here
              </.styled_link>
            </:item>
            <:item>
              Run verification later and go to site settings?
              <.styled_link href={"/#{URI.encode_www_form(@domain)}/settings/general"}>
                Click here
              </.styled_link>
            </:item>
          </.focus_list>
          <div
            :if={@verification_state && @super_admin? && @finished?}
            class="flex flex-col dark:text-gray-200 mt-4 pt-4 border-t border-gray-300 dark:border-gray-700"
            x-data="{ showDiagnostics: false }"
            id="super-admin-report"
          >
            <p class="text-sm">
              <a
                href="#"
                @click.prevent="showDiagnostics = !showDiagnostics"
                class="bg-yellow-100 dark:text-gray-800"
              >
                As a super-admin, you're eligible to see diagnostics details. Click to expand.
              </a>
            </p>
            <div x-show="showDiagnostics" x-cloak>
              <.focus_list>
                <:item :for={{diag, value} <- Map.from_struct(@verification_state.diagnostics)}>
                  <span class="text-sm">
                    {Phoenix.Naming.humanize(diag)}: <span class="font-mono">{value}</span>
                  </span>
                </:item>
              </.focus_list>
            </div>
          </div>
        </:footer>
      </.focus_box>
    </div>
    """
  end
end
