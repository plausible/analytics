defmodule PlausibleWeb.Live.InstallationV2.Instructions do
  @moduledoc """
  Instruction forms and components for InstallationV2 module
  """
  use PlausibleWeb, :component

  attr :tracker_script_configuration_form, :map, required: true

  def manual_instructions(assigns) do
    ~H"""
    <.title class="mt-4">
      Script installation
    </.title>

    <div class="text-sm my-4 leading-6">
      Paste this snippet into the <code>&lt;head&gt;</code>
      section of your site. See our
      <.styled_link href="https://plausible.io/docs/integration-guides" new_tab={true}>
        installation guides.
      </.styled_link>
      Once done, click the button below to verify your installation.
    </div>

    <.snippet_form
      text={render_snippet(@tracker_script_configuration_form.data)}
      rows={6}
      resizable={true}
    />
    <.h2 class="mt-8 text-sm font-medium">Optional measurements</.h2>
    <.script_config_control
      field={@tracker_script_configuration_form[:outbound_links]}
      label="Outbound links"
      tooltip="Automatically track clicks on external links. These count towards your billable pageviews."
      learn_more="https://plausible.io/docs/outbound-link-click-tracking"
    />
    <.script_config_control
      field={@tracker_script_configuration_form[:file_downloads]}
      label="File downloads"
      tooltip="Automatically track file downloads. These count towards your billable pageviews."
      learn_more="https://plausible.io/docs/file-downloads-tracking"
    />
    <.script_config_control
      field={@tracker_script_configuration_form[:form_submissions]}
      label="Form submissions"
      tooltip="Automatically track form submissions. These count towards your billable pageviews."
      learn_more="https://plausible.io/docs/form-submissions-tracking"
    />

    <.disclosure>
      <.disclosure_button class="mt-4 flex items-center group">
        <.h2 class="text-sm font-medium">Advanced options</.h2>
        <Heroicons.chevron_down mini class="size-4 ml-1 mt-0.5 group-data-[open=true]:rotate-180" />
      </.disclosure_button>
      <.disclosure_panel>
        <ul class="list-disc list-inside mt-2 space-y-2">
          <.advanced_option
            variant="tagged-events"
            label="Manual tagging"
            tooltip="Tag site elements like buttons, links and forms to track user activity. These count towards your billable pageviews. Additional action required."
            learn_more="https://plausible.io/docs/custom-event-goals"
          />
          <.advanced_option
            variant="404"
            label="404 error pages"
            tooltip="Find 404 error pages on your site. These count towards your billable pageviews. Additional action required."
            learn_more="https://plausible.io/docs/error-pages-tracking-404"
          />
          <.advanced_option
            variant="hash"
            label="Hashed page paths"
            tooltip="Automatically track page paths that use a # in the URL."
            learn_more="https://plausible.io/docs/hash-based-routing"
          />
          <.advanced_option
            variant="pageview-props"
            label="Custom properties"
            tooltip="Attach custom properties (also known as custom dimensions) to pageviews or custom events to create custom metrics. Additional action required."
            learn_more="https://plausible.io/docs/custom-props/introduction"
          />
          <.advanced_option
            variant="revenue"
            label="Ecommerce revenue"
            tooltip="Assign monetary values to purchases and track revenue attribution. Additional action required."
            learn_more="https://plausible.io/docs/ecommerce-revenue-tracking"
          />
        </ul>
      </.disclosure_panel>
    </.disclosure>
    """
  end

  attr :flow, :string, required: true
  attr :recommended_installation_type, :string, required: true

  def wordpress_instructions(assigns) do
    ~H"""
    <.title class="mt-4">
      WordPress installation
    </.title>
    <div class="text-sm mt-4 leading-6">
      <div class="mb-4">
        <span :if={@recommended_installation_type == "wordpress"}>
          We've detected your website is using WordPress. Here's how to integrate Plausible:
        </span>
        <span :if={@recommended_installation_type != "wordpress"}>
          Using Wordpress? Here's how to integrate Plausible:
        </span>
      </div>
      <.focus_list>
        <:item>
          <.styled_link href="https://plausible.io/wordpress-analytics-plugin" new_tab={true}>
            Install our WordPress plugin
          </.styled_link>
        </:item>
        <:item>
          After activating our plugin, click the button below to verify your installation.
        </:item>
      </.focus_list>
    </div>
    """
  end

  attr :recommended_installation_type, :string, required: true
  attr :tracker_script_configuration_form, :map, required: true

  def gtm_instructions(assigns) do
    ~H"""
    <.title class="mt-4">
      Tag Manager installation
    </.title>
    <div class="text-sm mt-4 leading-6">
      <span :if={@recommended_installation_type == "gtm"}>
        We've detected your website is using Google Tag Manager. Here's how to integrate Plausible:
      </span>
      <span :if={@recommended_installation_type != "gtm"}>
        Using Google Tag Manager? Here's how to integrate Plausible:
      </span>
      <div class="mt-4">
        <.focus_list>
          <:item>
            Copy your site's Script ID:
            <.snippet_form
              text={@tracker_script_configuration_form.data.id}
              rows={1}
              resizable={false}
            />
          </:item>

          <:item>
            <.styled_link href="https://plausible.io/gtm-template" new_tab={true}>
              Install the Plausible template in GTM
            </.styled_link>
          </:item>

          <:item>
            Paste your Script ID into the template and click the button below to verify your installation.
          </:item>
        </.focus_list>
      </div>
    </div>
    """
  end

  def npm_instructions(assigns) do
    ~H"""
    <.title class="my-4">
      NPM installation
    </.title>
    <.focus_list>
      <:item>
        <.styled_link href="https://www.npmjs.com/package/@plausible-analytics/tracker" new_tab={true}>
          Install @plausible-analytics/tracker NPM package
        </.styled_link>
      </:item>
      <:item>
        Once done, click the button below to verify your installation.
      </:item>
    </.focus_list>
    """
  end

  attr :field, :any, required: true
  attr :label, :string, required: true
  attr :tooltip, :string, required: true
  attr :learn_more, :string, required: true

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

  defp snippet_form(assigns) do
    ~H"""
    <div class="relative">
      <textarea
        id="snippet"
        class={"w-full border-1 border-gray-300 rounded-md p-4 text-sm text-gray-700 dark:border-gray-500 dark:bg-gray-900 dark:text-gray-300 #{if !@resizable, do: "resize-none"}"}
        rows={@rows}
        readonly
      ><%= @text %></textarea>

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
    """
  end

  defp render_snippet(tracker_script_configuration) do
    """
    <!-- Privacy-friendly analytics by Plausible -->
    <script async src="#{tracker_url(tracker_script_configuration)}"></script>
    <script>
      window.plausible=window.plausible||function(){(plausible.q=plausible.q||[]).push(arguments)},plausible.init=plausible.init||function(i){plausible.o=i||{}};
      plausible.init()
    </script>
    """
  end

  defp tracker_url(tracker_script_configuration) do
    "#{PlausibleWeb.Endpoint.url()}/js/#{tracker_script_configuration.id}.js"
  end
end
