defmodule PlausibleWeb.Live.Components.Verification do
  @moduledoc """
  This component is responsible for rendering the verification progress
  and diagnostics as a compact banner on top of the dashboard.
  """
  use Phoenix.LiveComponent
  use Plausible

  alias PlausibleWeb.Router.Helpers, as: Routes
  alias PlausibleWeb.Components.Icons
  alias PlausibleWeb.Live.Installation.Instructions
  alias Plausible.InstallationSupport.{State, Result}
  alias Plausible.Site.TrackerScriptConfiguration

  import PlausibleWeb.Components.Generic
  import PlausibleWeb.Live.Components.Form

  @container_id "verification-ui"
  # Dismissing hides the banner immediately and strips `verify_installation`
  # from the URL (the same param that got it rendered in the first place -
  # see PlausibleWeb.StatsController), so a refresh doesn't bring it back.
  @dismiss_onclick "document.getElementById('#{@container_id}').classList.add('hidden');" <>
                     "var u = new window.URL(window.location.href);" <>
                     "u.searchParams.delete('verify_installation');" <>
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
  attr(:custom_url_input?, :boolean, default: false)
  attr(:tracker_script_configuration, TrackerScriptConfiguration, default: nil)

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
        custom_url_input?={@custom_url_input?}
        tracker_script_configuration={@tracker_script_configuration}
      />
    </div>
    """
  end

  defp render_progress(assigns) do
    ~H"""
    <.notice title="Verifying your installation" theme={:gray}>
      <:icon>
        <div class="loading sm">
          <div></div>
        </div>
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
      <.super_admin_diagnostics
        :if={@super_admin? and not is_nil(@verification_state)}
        verification_state={@verification_state}
      />
    </.notice>
    """
  end

  defp render_failed(assigns) do
    assigns =
      assign(
        assigns,
        :expandable_instructions?,
        assigns.installation_type in ["manual", "gtm"] and
          not is_nil(assigns.tracker_script_configuration)
      )

    ~H"""
    <.notice
      title={
        if @interpretation,
          do: List.first(@interpretation.errors),
          else: "We couldn't verify your installation"
      }
      theme={:yellow}
    >
      <:icon>
        <Heroicons.exclamation_circle class="size-4.5 text-yellow-500" id="error-circle" />
      </:icon>
      <p :if={@interpretation} id="recommendation" class="mt-2">
        <span>{List.first(@interpretation.recommendations).text}.&nbsp;</span>
        <.styled_link href={List.first(@interpretation.recommendations).url} new_tab={true}>
          Learn more
        </.styled_link>
      </p>
      <div x-data="{ instructionsExpanded: false }">
        <div class="mt-5 flex flex-wrap items-center gap-2">
          <.retry_form_or_button custom_url_input?={@custom_url_input?} domain={@domain} />
          <.expand_installation_instructions_button
            :if={@expandable_instructions?}
            installation_type={@installation_type}
          />
          <.review_instructions_link
            :if={@installation_type in ["wordpress", "npm"]}
            installation_type={@installation_type}
          />
        </div>
        <.expandable_installation_instructions
          :if={@expandable_instructions?}
          installation_type={@installation_type}
          tracker_script_configuration={@tracker_script_configuration}
        />
      </div>
      <.additional_help_links
        custom_url_input?={@custom_url_input?}
        interpretation={@interpretation}
        attempts={@attempts}
        domain={@domain}
        flow={@flow}
      />
      <.super_admin_diagnostics
        :if={@super_admin? and not is_nil(@verification_state)}
        verification_state={@verification_state}
      />
    </.notice>
    """
  end

  defp retry_form_or_button(%{custom_url_input?: true} = assigns) do
    ~H"""
    <form phx-submit="verify-custom-url" class="flex items-center gap-2">
      <.input
        type="url"
        name="custom_url"
        id="custom_url"
        aria-label="Website URL"
        required
        mt?={false}
        width="w-44"
        placeholder={"https://#{@domain}"}
        value={"https://#{@domain}"}
      />
      <.button type="submit" mt?={false} theme="secondary" size="sm">
        Check again
      </.button>
    </form>
    """
  end

  defp retry_form_or_button(assigns) do
    ~H"""
    <.button_link
      mt?={false}
      href="#"
      phx-click="retry"
      theme="secondary"
      size="sm"
    >
      Check again
    </.button_link>
    """
  end

  defp expand_installation_instructions_button(assigns) do
    ~H"""
    <span x-on:click.prevent="instructionsExpanded = !instructionsExpanded">
      <.button_link
        mt?={false}
        href="#"
        theme="ghost"
        size="sm"
        class="hover:bg-gray-900/10 dark:hover:bg-white/10 hover:border-transparent dark:hover:border-transparent"
      >
        <span class="inline-flex items-center gap-0.5">
          {review_instructions_label(@installation_type)}
          <span x-show="!instructionsExpanded" x-cloak>
            <Heroicons.chevron_down mini class="size-4" />
          </span>
          <span x-show="instructionsExpanded" x-cloak>
            <Heroicons.chevron_up mini class="size-4" />
          </span>
        </span>
      </.button_link>
    </span>
    """
  end

  defp review_instructions_link(assigns) do
    ~H"""
    <.button_link
      mt?={false}
      href={install_help_href(@installation_type)}
      theme="ghost"
      size="sm"
      target="_blank"
      rel="noopener noreferrer"
      class="hover:bg-gray-900/10 dark:hover:bg-white/10 hover:border-transparent dark:hover:border-transparent"
    >
      Review instructions <Icons.external_link_icon class="inline-block size-3.5 ml-1" />
    </.button_link>
    """
  end

  defp expandable_installation_instructions(assigns) do
    ~H"""
    <div x-show="instructionsExpanded" x-cloak class="mt-5">
      <Instructions.copy_snippet_box
        :if={@installation_type == "manual"}
        tracker_script_configuration={@tracker_script_configuration}
      />
      <Instructions.gtm_instructions_content_inner
        :if={@installation_type == "gtm"}
        tracker_script_configuration={@tracker_script_configuration}
      />
    </div>
    """
  end

  defp additional_help_links(assigns) do
    ~H"""
    <div class="mt-5">
      <ul class="list-disc space-y-2 ml-4 text-sm">
        <li :if={
          not @custom_url_input? && @interpretation && is_map(@interpretation.data) &&
            @interpretation.data[:offer_custom_url_input]
        }>
          Is your website located at a different URL?
          <.styled_link href="#" phx-click="show-custom-url-form" id="verify-custom-url-link">
            Click here
          </.styled_link>
        </li>
        <li :if={ee?() and @attempts >= 3}>
          Need further help with your installation?
          <.styled_link href="https://plausible.io/contact">
            Contact us
          </.styled_link>
        </li>
        <li>
          Want to choose another installation method?
          <.styled_link href={
            Routes.site_path(PlausibleWeb.Endpoint, :installation, @domain, flow: @flow)
          }>
            Click here
          </.styled_link>
        </li>
      </ul>
    </div>
    """
  end

  defp super_admin_diagnostics(assigns) do
    ~H"""
    <div
      class="mt-5 flex flex-col dark:text-gray-200"
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

  defp review_instructions_label("manual"), do: "View snippet"
  defp review_instructions_label(_installation_type), do: "Review instructions"

  defp install_help_href("wordpress"), do: "https://plausible.io/wordpress-analytics-plugin"

  defp install_help_href("npm"),
    do: "https://www.npmjs.com/package/@plausible-analytics/tracker"
end
