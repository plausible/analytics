defmodule PlausibleWeb.Live.TrackingSettings do
  @moduledoc """
  LiveView for the tracking tile on the site general settings page. Shows the
  installation status, allows toggling the measurements that are tracked
  automatically, and lists the ones that require manual setup.
  """
  use PlausibleWeb, :live_view

  alias PlausibleWeb.Components.Icons

  @toggleable_fields %{
    "outbound_links" => "Outbound link tracking",
    "file_downloads" => "File download tracking",
    "form_submissions" => "Form submission tracking"
  }

  @completed_onboarding_statuses [:verification_succeeded, :first_pageview, :completed]

  def mount(_params, %{"domain" => domain}, socket) do
    socket =
      socket
      |> assign_new(:site, fn %{current_user: current_user} ->
        Plausible.Sites.get_for_user!(current_user, domain,
          roles: [:owner, :admin, :editor, :super_admin]
        )
      end)

    {:ok,
     socket
     |> assign(
       tracker_script_configuration:
         PlausibleWeb.Tracker.get_or_create_tracker_script_configuration!(socket.assigns.site)
     )
     |> assign_installation_status()}
  end

  def render(assigns) do
    ~H"""
    <div id="tracking-settings-main">
      <.flash_messages flash={@flash} />

      <.tile docs={if ce?(), do: "plausible-script"}>
        <:title>Tracking</:title>
        <:subtitle>Manage how Plausible collects data for this site.</:subtitle>

        <div class="flex flex-col gap-6">
          <.settings_row
            label={if @installation_status, do: "Site installation"}
            docs="plausible-script"
          >
            <.status_indicator :if={@installation_status} status={@installation_status} />
            <.styled_link
              href={review_installation_path(@site)}
              aria-label="View setup"
              class="text-sm"
            >
              Review
            </.styled_link>
          </.settings_row>

          <.settings_divider />

          <.settings_section
            title="Default tracking"
            tooltip="Automatically track these events for your site."
          >
            <.measurement label="Outbound links">
              <:icon><Heroicons.link class="size-4.5" /></:icon>
              <.toggle_switch
                id="outbound_links"
                checked={@tracker_script_configuration.outbound_links}
                phx-click="toggle"
                phx-value-field="outbound_links"
              />
            </.measurement>
            <.measurement label="File downloads">
              <:icon><Heroicons.arrow_down_tray class="size-4.5" /></:icon>
              <.toggle_switch
                id="file_downloads"
                checked={@tracker_script_configuration.file_downloads}
                phx-click="toggle"
                phx-value-field="file_downloads"
              />
            </.measurement>
            <.measurement label="Form submissions">
              <:icon><Icons.button_click_icon class="size-4.5" /></:icon>
              <.toggle_switch
                id="form_submissions"
                checked={@tracker_script_configuration.form_submissions}
                phx-click="toggle"
                phx-value-field="form_submissions"
              />
            </.measurement>
          </.settings_section>

          <.settings_divider />

          <.settings_section
            title="Additional tracking"
            tooltip="Require manual setup and count towards your billable monthly pageviews."
            expandable?={true}
          >
            <.measurement label="Custom event tracking">
              <:icon><Heroicons.check_circle class="size-4.5" /></:icon>
              <.learn_more href="https://plausible.io/docs/custom-event-goals" />
            </.measurement>
            <.measurement label="404 error pages">
              <:icon><Icons.error_page_icon class="size-4.5" /></:icon>
              <.learn_more href="https://plausible.io/docs/error-pages-tracking-404" />
            </.measurement>
            <.measurement label="Hashed page paths">
              <:icon><Heroicons.hashtag class="size-4.5" /></:icon>
              <.learn_more href="https://plausible.io/docs/hash-based-routing" />
            </.measurement>
            <.measurement label="Custom properties">
              <:icon><Icons.tag_icon class="size-4.5" /></:icon>
              <.learn_more href="https://plausible.io/docs/custom-props/introduction" />
            </.measurement>
            <.measurement label="Ecommerce revenue">
              <:icon><Heroicons.shopping_cart class="size-4.5" /></:icon>
              <.learn_more href="https://plausible.io/docs/ecommerce-revenue-tracking" />
            </.measurement>
          </.settings_section>
        </div>
      </.tile>
    </div>
    """
  end

  def handle_event("toggle", %{"field" => field}, socket)
      when is_map_key(@toggleable_fields, field) do
    configuration = socket.assigns.tracker_script_configuration
    enabled? = not Map.fetch!(configuration, String.to_existing_atom(field))

    updated_configuration =
      PlausibleWeb.Tracker.update_script_configuration!(
        socket.assigns.site,
        %{field => enabled?},
        :installation
      )

    message =
      "#{Map.fetch!(@toggleable_fields, field)} #{if enabled?, do: "enabled", else: "disabled"}"

    {:noreply,
     socket
     |> assign(tracker_script_configuration: updated_configuration)
     |> put_live_flash(:success, message)}
  end

  defp status_indicator(%{status: :completed} = assigns) do
    ~H"""
    <div class="flex items-center gap-1.5 text-gray-800 dark:text-gray-200">
      <span class="size-2 rounded-full bg-green-500"></span> Completed
    </div>
    """
  end

  defp status_indicator(%{status: :pending} = assigns) do
    ~H"""
    <div class="flex items-center gap-1.5 text-gray-800 dark:text-gray-200">
      <span class="size-2 rounded-full bg-yellow-500"></span> Pending
    </div>
    """
  end

  attr :label, :string, required: true
  slot :icon, required: true
  slot :inner_block, required: true

  defp measurement(assigns) do
    ~H"""
    <div class="flex items-center justify-between gap-4 text-sm">
      <div class="flex items-center gap-2 text-gray-800 dark:text-gray-200">
        {render_slot(@icon)}
        {@label}
      </div>
      {render_slot(@inner_block)}
    </div>
    """
  end

  attr :href, :string, required: true

  defp learn_more(assigns) do
    ~H"""
    <.tooltip centered?={true}>
      <:tooltip_content>Learn more</:tooltip_content>
      <.button_link
        theme="icon"
        size="xs"
        mt?={false}
        href={@href}
        target="_blank"
        rel="noopener noreferrer"
        aria-label="Learn more"
      >
        <Icons.external_link_icon class="size-4 [&_path]:stroke-2" />
      </.button_link>
    </.tooltip>
    """
  end

  defp review_installation_path(site) do
    Routes.site_path(PlausibleWeb.Endpoint, :installation, site.domain,
      flow: PlausibleWeb.Flows.review()
    )
  end

  defp assign_installation_status(socket) do
    status =
      cond do
        ce?() -> nil
        socket.assigns.site.onboarding_status in @completed_onboarding_statuses -> :completed
        true -> :pending
      end

    assign(socket, installation_status: status)
  end
end
