defmodule PlausibleWeb.Live.InstallationV2 do
  @moduledoc """
  User assistance module around Plausible installation instructions/onboarding
  """
  use PlausibleWeb, :live_view

  def mount(
        %{"domain" => domain},
        _session,
        socket
      ) do
    site =
      Plausible.Sites.get_for_user!(socket.assigns.current_user, domain, [
        :owner,
        :admin,
        :editor,
        :super_admin,
        :viewer
      ])

    {:ok,
     assign(socket,
       site: site,
       installation_form: to_form(site.installation_meta.script_config),
       flow: "provisioning",
       installation_type: "manual"
     )}
  end

  def render(assigns) do
    ~H"""
    <div>
      <PlausibleWeb.Components.FlowProgress.render flow={@flow} current_step="Install Plausible" />

      <.focus_box>
        <:title>
          Manual installation
        </:title>

        <:subtitle :if={@installation_type == "manual"}>
          Paste this snippet into the <code>&lt;head&gt;</code>
          section of your site. See our
          <.styled_link href="https://plausible.io/docs/integration-guides" new_tab={true}>
            installation guides.
          </.styled_link>
          Once done, click the button below to verify your installation.
        </:subtitle>

        <div :if={@installation_type in ["manual", "GTM"]}>
          <.snippet_form
            installation_form={@installation_form}
            installation_type={@installation_type}
            flow={@flow}
            site={@site}
          />
        </div>
      </.focus_box>
    </div>
    """
  end

  defp snippet_form(assigns) do
    ~H"""
    <form id="snippet-form">
      <div class="relative">
        <textarea
          id="snippet"
          class="w-full border-1 border-gray-300 rounded-md p-4 text-sm text-gray-700 dark:border-gray-500 dark:bg-gray-900 dark:text-gray-300"
          rows="5"
          readonly
        ><%= render_snippet(@installation_type, @site) %></textarea>

        <a
          onclick="var input = document.getElementById('snippet'); input.focus(); input.select(); document.execCommand('copy'); event.stopPropagation();"
          href="javascript:void(0)"
          class="absolute flex items-center text-xs font-medium text-indigo-600 no-underline hover:underline bottom-2 right-4 p-2 bg-white dark:bg-gray-900"
        >
          <Heroicons.document_duplicate class="pr-1 text-indigo-600 dark:text-indigo-500 w-5 h-5" />
          <span>
            COPY
          </span>
        </a>
      </div>

      <.h2 class="mt-8 text-sm font-medium">Optional measurements</.h2>
      <.script_config_control
        field={@installation_form["outbound-links"]}
        label="Outbound links"
        tooltip="Automatically track clicks on external links. These count towards your billable pageviews."
        learn_more="https://plausible.io/docs/outbound-link-click-tracking"
      />
      <.script_config_control
        field={@installation_form["file-downloads"]}
        label="File downloads"
        tooltip="Automatically track file downloads. These count towards your billable pageviews."
        learn_more="https://plausible.io/docs/file-downloads-tracking"
      />
      <.script_config_control
        field={@installation_form["form-submissions"]}
        label="Form submissions"
        tooltip="Automatically track form submissions. These count towards your billable pageviews."
        learn_more="https://plausible.io/docs/form-submissions-tracking"
      />
      <.script_config_control
        field={@installation_form["tagged-events"]}
        label="Manual tagging"
        tooltip="Tag site elements like buttons, links and forms to track user activity. These count towards your billable pageviews. Additional action required."
        learn_more="https://plausible.io/docs/custom-event-goals"
      />

      <.disclosure>
        <.disclosure_button class="mt-8 flex items-center group">
          <.h2 class="text-sm font-medium">Advanced options</.h2>
          <Heroicons.chevron_down mini class="size-4 ml-1 mt-0.5 group-data-[open=true]:rotate-180" />
        </.disclosure_button>
        <.disclosure_panel>
          <ul class="list-disc list-inside mt-2 space-y-2">
            <.advanced_option
              config={@site.installation_meta.script_config}
              variant="404"
              label="404 error pages"
              tooltip="Find 404 error pages on your site. These count towards your billable pageviews. Additional action required."
              learn_more="https://plausible.io/docs/error-pages-tracking-404"
            />
            <.advanced_option
              config={@site.installation_meta.script_config}
              variant="hash"
              label="Hashed page paths"
              tooltip="Automatically track page paths that use a # in the URL."
              learn_more="https://plausible.io/docs/hash-based-routing"
            />
            <.advanced_option
              config={@site.installation_meta.script_config}
              variant="pageview-props"
              label="Custom properties"
              tooltip="Attach custom properties (also known as custom dimensions) to pageviews or custom events to create custom metrics. Additional action required."
              learn_more="https://plausible.io/docs/custom-props/introduction"
            />
            <.advanced_option
              config={@site.installation_meta.script_config}
              variant="revenue"
              label="Ecommerce revenue"
              tooltip="Assign monetary values to purchases and track revenue attribution. Additional action required."
              learn_more="https://plausible.io/docs/ecommerce-revenue-tracking"
            />
          </ul>
        </.disclosure_panel>
      </.disclosure>

      <.button_link
        :if={not is_nil(@installation_type)}
        href={"/#{URI.encode_www_form(@site.domain)}/verification"}
        type="submit"
        class="w-full mt-8"
      >
        <%= if @flow == PlausibleWeb.Flows.domain_change() do %>
          I understand, I'll update my website
        <% else %>
          <%= if @flow == PlausibleWeb.Flows.review() do %>
            Verify your installation
          <% else %>
            Start collecting data
          <% end %>
        <% end %>
      </.button_link>
    </form>
    """
  end

  defp script_config_control(assigns) do
    ~H"""
    <div class="mt-2 p-1 text-sm">
      <div class="flex items-center">
        <.input mt?={false} field={@field} label={@label} type="checkbox" />
        <div class="ml-2 collapse md:visible">
          <.tooltip sticky?={false}>
            <:tooltip_content>
              {@tooltip}
              <br /><br />Click to learn more.
            </:tooltip_content>
            <a href={@learn_more} target="_blank" rel="noopener noreferrer">
              <Heroicons.information_circle class="text-indigo-700 dark:text-gray-500 w-5 h-5 hover:stroke-2" />
            </a>
          </.tooltip>
        </div>
        <div class="ml-2 visible md:invisible">
          <a href={@learn_more} target="_blank" rel="noopener noreferrer">
            <Heroicons.information_circle class="text-indigo-700 dark:text-gray-500 w-5 h-5 hover:stroke-2" />
          </a>
        </div>
      </div>
    </div>
    """
  end

  defp advanced_option(assigns) do
    ~H"""
    <li class="p-1 text-sm">
      <div class="inline-flex items-center">
        <div>{@label}</div>
        <div class="ml-2 collapse md:visible">
          <.tooltip sticky?={false}>
            <:tooltip_content>
              {@tooltip}
              <br /><br />Click to learn more.
            </:tooltip_content>
            <a href={@learn_more} target="_blank" rel="noopener noreferrer">
              <Heroicons.information_circle class="text-indigo-700 dark:text-gray-500 w-5 h-5 hover:stroke-2" />
            </a>
          </.tooltip>
        </div>
        <div class="ml-2 visible md:invisible">
          <a href={@learn_more} target="_blank" rel="noopener noreferrer">
            <Heroicons.information_circle class="text-indigo-700 dark:text-gray-500 w-5 h-5 hover:stroke-2" />
          </a>
        </div>
      </div>
    </li>
    """
  end

  defp render_snippet("manual", site) do
    """
    <script defer src="#{tracker_url(site)}"></script>
    <script>window.plausible = window.plausible || function() { (window.plausible.q = window.plausible.q || []).push(arguments) }</script>
    """
  end

  defp tracker_url(site) do
    "https://plausible.io/js/script-#{site.domain}.js"
  end
end
