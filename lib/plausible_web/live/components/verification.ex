defmodule PlausibleWeb.Live.Components.Verification do
  @moduledoc """
  This component is responsible for rendering the verification progress
  and diagnostics as a compact banner on top of the dashboard.
  """
  use Phoenix.LiveComponent
  use Plausible

  alias PlausibleWeb.Router.Helpers, as: Routes
  alias Plausible.InstallationSupport.{State, Result}

  import PlausibleWeb.Components.Generic

  @container_id "verification-ui"
  # Dismissing hides the banner immediately and strips `verify_installation`
  # from the URL (the same param that got it rendered in the first place -
  # see PlausibleWeb.StatsController), so a refresh doesn't bring it back.
  @dismiss_onclick "document.getElementById('#{@container_id}').classList.add('hidden');" <>
                     "var u = new window.URL(window.location.href);" <>
                     "u.searchParams.delete('verify_installation');" <>
                     "u.searchParams.delete('installation_type');" <>
                     "u.searchParams.delete('flow');" <>
                     "window.history.replaceState(null, '', u);"

  attr(:domain, :string, required: true)

  attr(:message, :string,
    default: "We're visiting your site to ensure that everything is working"
  )

  attr(:super_admin?, :boolean, default: false)
  attr(:finished?, :boolean, default: false)
  attr(:success?, :boolean, default: false)
  attr(:verification_state, State, default: nil)
  attr(:interpretation, Result, default: nil)
  attr(:attempts, :integer, default: 0)
  attr(:flow, :string, default: "")
  attr(:installation_type, :string, default: nil)
  attr(:awaiting_first_pageview?, :boolean, default: false)

  def render(assigns) do
    assigns =
      assigns
      |> assign(:dismiss_onclick, @dismiss_onclick)
      |> assign(:container_id, @container_id)

    ~H"""
    <div id={@container_id} class="relative mb-4">
      <button
        type="button"
        aria-label="Dismiss"
        class="absolute right-2 top-2 z-10 rounded p-1 text-gray-400 hover:text-gray-600 dark:text-gray-500 dark:hover:text-gray-300"
        onclick={@dismiss_onclick}
      >
        <Heroicons.x_mark class="size-4" />
      </button>
      <.render_progress :if={not @finished?} message={@message} />
      <.render_success
        :if={@finished? and @success?}
        awaiting_first_pageview?={@awaiting_first_pageview?}
        domain={@domain}
        super_admin?={@super_admin?}
        verification_state={@verification_state}
      />
      <.render_failed
        :if={@finished? and not @success?}
        interpretation={@interpretation}
        attempts={@attempts}
        domain={@domain}
        flow={@flow}
        installation_type={@installation_type}
        super_admin?={@super_admin?}
        verification_state={@verification_state}
      />
    </div>
    """
  end

  defp render_progress(assigns) do
    ~H"""
    <.notice title="Verifying your installation" theme={:gray}>
      <:icon>
        <div class="block pulsating-circle" />
      </:icon>
      <p class="animate-pulse" id="progress">{@message}</p>
    </.notice>
    """
  end

  defp render_success(assigns) do
    ~H"""
    <.notice title="Success!" theme={:gray} icon_class="text-green-600 dark:text-green-500">
      <:icon>
        <Heroicons.check_badge class="size-4.5 text-green-600 dark:text-green-500" id="check-circle" />
      </:icon>
      Your installation is working and visitors are being counted accurately.
      <span :if={@awaiting_first_pageview?} id="awaiting" class="animate-pulse">
        Awaiting your first pageview...
      </span>
      <.super_admin_diagnostics
        :if={@super_admin? and not is_nil(@verification_state)}
        verification_state={@verification_state}
      />
    </.notice>
    """
  end

  defp render_failed(assigns) do
    ~H"""
    <.notice
      title={
        if @interpretation,
          do: List.first(@interpretation.errors),
          else: "We couldn't verify your installation"
      }
      theme={:red}
    >
      <:icon>
        <Heroicons.exclamation_triangle
          class="size-4.5 text-red-600 dark:text-red-500"
          id="error-circle"
        />
      </:icon>
      <:actions>
        <.button_link mt?={false} href="#" phx-click="retry" size="sm">
          Verify installation again
        </.button_link>
      </:actions>
      <p :if={@interpretation} id="recommendation">
        <span>{List.first(@interpretation.recommendations).text}.&nbsp;</span>
        <.styled_link href={List.first(@interpretation.recommendations).url} new_tab={true}>
          Learn more
        </.styled_link>
      </p>
      <p class="mt-1.5 flex flex-wrap gap-x-4">
        <span :if={
          @interpretation && is_map(@interpretation.data) &&
            @interpretation.data[:offer_custom_url_input]
        }>
          Is your website located at a different URL?
          <.styled_link href="#" phx-click="show-custom-url-form" id="verify-custom-url-link">
            Click here
          </.styled_link>
        </span>
        <span :if={ee?() and @attempts >= 3}>
          Need further help with your installation?
          <.styled_link href="https://plausible.io/contact">
            Contact us
          </.styled_link>
        </span>
        <span>
          Need to see installation instructions again?
          <.styled_link href={
            Routes.site_path(PlausibleWeb.Endpoint, :installation, @domain,
              flow: @flow,
              installation_type: @installation_type
            )
          }>
            Click here
          </.styled_link>
        </span>
      </p>
      <.super_admin_diagnostics
        :if={@super_admin? and not is_nil(@verification_state)}
        verification_state={@verification_state}
      />
    </.notice>
    """
  end

  defp super_admin_diagnostics(assigns) do
    ~H"""
    <div
      class="mt-3 flex flex-col dark:text-gray-200"
      x-data="{ showDiagnostics: false }"
      id="super-admin-report"
    >
      <p class="text-sm">
        <a
          href="#"
          @click.prevent="showDiagnostics = !showDiagnostics"
          class="bg-yellow-100 dark:bg-yellow-800/40"
        >
          As a super-admin, you're eligible to see diagnostics details. Click to expand.
        </a>
      </p>
      <div x-show="showDiagnostics" x-cloak>
        <.focus_list>
          <:item :for={{diag, value} <- Map.from_struct(@verification_state.diagnostics)}>
            <span class="text-sm">
              {Phoenix.Naming.humanize(diag)}: <span class="font-mono">{to_string_value(value)}</span>
            </span>
          </:item>
        </.focus_list>
      </div>
    </div>
    """
  end

  defp to_string_value(value) when is_binary(value), do: value
  defp to_string_value(value), do: inspect(value)
end
