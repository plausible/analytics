defmodule PlausibleWeb.Live.InstallationV2 do
  @moduledoc """
  User assistance module around Plausible installation instructions/onboarding
  """
  use PlausibleWeb, :live_view
  alias Plausible.Verification.{Checks, State}

  def mount(
        %{"domain" => domain} = params,
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

    tracker_script_configuration =
      PlausibleWeb.Tracker.get_or_create_tracker_script_configuration!(site, %{
        outbound_links: true,
        form_submissions: true,
        file_downloads: true,
        installation_type: :manual
      })

    if connected?(socket) do
      Checks.run("https://#{site.domain}", site.domain,
        checks: [
          Checks.FetchBody,
          Checks.ScanBody
        ],
        report_to: self(),
        async?: true,
        slowdown: 0
      )
    end

    {:ok,
     assign(socket,
       site: site,
       tracker_script_configuration_form:
         to_form(
           Plausible.Site.TrackerScriptConfiguration.installation_changeset(
             tracker_script_configuration,
             %{}
           )
         ),
       flow: params["flow"] || "provisioning",
       installation_type: get_installation_type(params, tracker_script_configuration),
       detected_installation_type: nil
     )}
  end

  def handle_info({:verification_end, %State{} = state}, socket) do
    installation_type =
      case state.diagnostics do
        %{wordpress_likely?: true} -> "wordpress"
        %{gtm_likely?: true} -> "gtm"
        _ -> "manual"
      end

    {:noreply,
     assign(socket,
       detected_installation_type: installation_type
     )}
  end

  def handle_info({:verification_check_start, _}, socket) do
    {:noreply, socket}
  end

  def handle_params(params, _url, socket) do
    {:noreply,
     assign(socket,
       installation_type:
         get_installation_type(params, socket.assigns.tracker_script_configuration_form.data)
     )}
  end

  def render(assigns) do
    ~H"""
    <div>
      <PlausibleWeb.Components.FlowProgress.render flow={@flow} current_step="Install Plausible" />

      <.focus_box>
        <div class="flex flex-row gap-2 bg-gray-100 rounded-md p-1">
          <.tab patch="?type=manual" selected={@installation_type == "manual"}>
            <.script_icon /> Script
          </.tab>
          <.tab patch="?type=wordpress" selected={@installation_type == "wordpress"}>
            <.wordpress_icon /> WordPress
          </.tab>
          <.tab patch="?type=gtm" selected={@installation_type == "gtm"}>
            <.tag_manager_icon /> Tag Manager
          </.tab>
          <.tab patch="?type=npm" selected={@installation_type == "npm"}>
            <.npm_icon /> NPM
          </.tab>
        </div>

        <div
          :if={@flow == PlausibleWeb.Flows.provisioning() and is_nil(@detected_installation_type)}
          class="flex items-center justify-center py-8"
        >
          <.spinner class="w-6 h-6" />
        </div>

        <.form
          :if={@flow != PlausibleWeb.Flows.provisioning() or not is_nil(@detected_installation_type)}
          for={@tracker_script_configuration_form}
          phx-submit="submit"
          class="mt-4"
        >
          <.input
            type="hidden"
            field={@tracker_script_configuration_form[:installation_type]}
            value={@installation_type}
          />
          <.manual_instructions
            :if={@installation_type == "manual"}
            tracker_script_configuration_form={@tracker_script_configuration_form}
          />

          <.wordpress_instructions :if={@installation_type == "wordpress"} flow={@flow} />
          <.gtm_instructions :if={@installation_type == "gtm"} />
          <.npm_instructions :if={@installation_type == "npm"} />

          <.button type="submit" class="w-full mt-8">
            <%= if @flow == PlausibleWeb.Flows.review() do %>
              Verify your installation
            <% else %>
              Start collecting data
            <% end %>
          </.button>
        </.form>
      </.focus_box>
    </div>
    """
  end

  attr :tracker_script_configuration_form, :map, required: true

  defp manual_instructions(assigns) do
    ~H"""
    <.title class="mt-4">
      Script installation
    </.title>

    <div class="text-sm mt-4 leading-6">
      Paste this snippet into the <code>&lt;head&gt;</code>
      section of your site. See our
      <.styled_link href="https://plausible.io/docs/integration-guides" new_tab={true}>
        installation guides.
      </.styled_link>
      Once done, click the button below to verify your installation.
    </div>

    <.snippet_form tracker_script_configuration={@tracker_script_configuration_form.data} />
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

  defp wordpress_instructions(assigns) do
    ~H"""
    <.title class="mt-4">
      WordPress installation
    </.title>
    <div class="text-sm mt-4 leading-6">
      Using WordPress? Here's how to integrate Plausible:
      <.focus_list>
        <:item>
          <.styled_link href="https://plausible.io/wordpress-analytics-plugin" new_tab={true}>
            Install our WordPress plugin
          </.styled_link>
        </:item>
        <:item>
          After activating our plugin, click the button below to verify your installation
        </:item>
      </.focus_list>
    </div>
    """
  end

  defp gtm_instructions(assigns) do
    ~H"""
    <.title class="mt-4">
      Tag Manager installation
    </.title>
    <div class="text-sm mt-4 leading-6">
      Using Google Tag Manager? Here's how to integrate Plausible:
      <.focus_list>
        <:item>
          <.styled_link href="https://plausible.io/docs/google-tag-manager" new_tab={true}>
            Read our Tag Manager guide
          </.styled_link>
        </:item>
        <:item>
          Paste this snippet into GTM's Custom HTML section. Once done, click the button below to verify your installation.
        </:item>
      </.focus_list>
    </div>
    """
  end

  defp npm_instructions(assigns) do
    ~H"""
    <.title class="mt-4">
      NPM installation
    </.title>
    <div class="text-sm mt-4 leading-6">
      TBD
    </div>
    """
  end

  attr :selected, :boolean, default: false
  attr :patch, :string, required: true
  slot :inner_block, required: true

  defp tab(assigns) do
    assigns =
      if assigns[:selected] do
        assign(assigns, class: "bg-white rounded-md px-3.5 text-sm font-medium flex items-center")
      else
        assign(assigns,
          class:
            "bg-gray-100 rounded-md px-3.5 py-2.5 text-sm font-medium flex items-center cursor-pointer"
        )
      end

    ~H"""
    <.link patch={@patch} class={@class}>
      {render_slot(@inner_block)}
    </.link>
    """
  end

  defp snippet_form(assigns) do
    ~H"""
    <div class="relative">
      <textarea
        id="snippet"
        class="w-full border-1 border-gray-300 rounded-md p-4 text-sm text-gray-700 dark:border-gray-500 dark:bg-gray-900 dark:text-gray-300 "
        rows="4"
        readonly
      ><%= render_snippet(@tracker_script_configuration) %></textarea>

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

  def handle_event("submit", %{"tracker_script_configuration" => params}, socket) do
    PlausibleWeb.Tracker.update_script_configuration(
      socket.assigns.site,
      params,
      :installation
    )

    {:noreply,
     push_navigate(socket,
       to:
         Routes.site_path(socket, :verification, socket.assigns.site.domain,
           flow: socket.assigns.flow
         )
     )}
  end

  defp render_snippet(tracker_script_configuration) do
    """
    <script>
    window.plausible=window.plausible||function(){(window.plausible.q=window.plausible.q||[]).push(arguments)},window.plausible.init=function(i){window.plausible.o=i||{}};var script=document.createElement("script");script.type="text/javascript",script.defer=!0,script.src="#{tracker_url(tracker_script_configuration)}";var r=document.getElementsByTagName("script")[0];r.parentNode.insertBefore(script,r);
    plausible.init()
    </script>
    """
  end

  defp tracker_url(tracker_script_configuration) do
    "https://plausible.io/js/s-#{tracker_script_configuration.id}.js"
  end

  defp script_icon(assigns) do
    ~H"""
    <svg
      xmlns="http://www.w3.org/2000/svg"
      class="w-4 h-4 mr-1"
      fill="none"
      viewBox="0 0 24 24"
      stroke-width="2"
      stroke="currentColor"
      class="size-6"
    >
      <path
        stroke-linecap="round"
        stroke-linejoin="round"
        d="M17.25 6.75 22.5 12l-5.25 5.25m-10.5 0L1.5 12l5.25-5.25m7.5-3-4.5 16.5"
      />
    </svg>
    """
  end

  defp wordpress_icon(assigns) do
    ~H"""
    <svg
      xmlns="http://www.w3.org/2000/svg"
      class="w-4 h-4 mr-1"
      viewBox="0 0 50 50"
      width="50px"
      height="50px"
    >
      <path d="M25,2C12.317,2,2,12.318,2,25s10.317,23,23,23s23-10.318,23-23S37.683,2,25,2z M25,7c4.26,0,8.166,1.485,11.247,3.955 c-0.956,0.636-1.547,1.74-1.547,2.945c0,1.6,0.9,3,1.9,4.6c0.8,1.3,1.6,3,1.6,5.4c0,1.7-0.5,3.8-1.5,6.4l-2,6.6l-7.1-21.2 c1.2-0.1,2.3-0.2,2.3-0.2c1-0.1,0.9-1.6-0.1-1.6c0,0,0,0-0.1,0c0,0-3.2,0.3-5.3,0.3c-1.9,0-5.2-0.3-5.2-0.3s0,0-0.1,0 c-1,0-1.1,1.6-0.1,1.6c0,0,1,0.1,2.1,0.2l3.1,8.4L19.9,37l-7.2-21.4c1.2-0.1,2.3-0.2,2.3-0.2c1-0.1,0.9-1.6-0.1-1.6c0,0,0,0-0.1,0 c0,0-2.152,0.202-4.085,0.274C14.003,9.78,19.168,7,25,7z M7,25c0-1.8,0.271-3.535,0.762-5.174l7.424,20.256 C10.261,36.871,7,31.323,7,25z M19.678,42.2L25,26.6l5.685,15.471C28.897,42.665,26.989,43,25,43 C23.147,43,21.36,42.719,19.678,42.2z M35.304,39.75L35.304,39.75L40.6,24.4c0.786-2,1.21-3.742,1.39-5.304 C42.633,20.947,43,22.928,43,25C43,31.111,39.954,36.497,35.304,39.75z" />
    </svg>
    """
  end

  defp tag_manager_icon(assigns) do
    ~H"""
    <svg xmlns="http://www.w3.org/2000/svg" class="w-4 h-4 mr-1 -ml-2" viewBox="0 0 80 80">
      <path
        d="M 40 3.0058594 C 38.232848 3.0058594 36.465803 3.6767752 35.125 5.0175781 L 5.0175781 35.125 C 2.3359722 37.806606 2.3359722 42.193394 5.0175781 44.875 L 35.125 74.982422 C 36.465803 76.323225 38.236969 77 40 77 C 41.763031 77 43.534197 76.323225 44.875 74.982422 L 74.982422 44.875 C 77.665111 42.193478 77.665111 37.806522 74.982422 35.125 L 44.875 5.0175781 C 43.534197 3.6767752 41.767152 3.0058594 40 3.0058594 z M 40 4.9960938 C 41.251848 4.9960936 42.50374 5.4744436 43.460938 6.4316406 L 73.568359 36.539062 C 75.48367 38.453541 75.48367 41.54646 73.568359 43.460938 L 43.460938 73.568359 C 42.50374 74.525556 41.254969 75 40 75 C 38.745031 75 37.49626 74.525556 36.539062 73.568359 L 6.4316406 43.460938 C 4.5172466 41.546543 4.5172466 38.453457 6.4316406 36.539062 L 36.539062 6.4316406 C 37.49626 5.4744436 38.748152 4.9960938 40 4.9960938 z M 52.681641 18.007812 C 52.386328 17.980859 52.083359 18.085812 51.880859 18.289062 C 51.790859 18.389062 51.710156 18.499141 51.660156 18.619141 C 51.610156 18.739141 51.589844 18.87 51.589844 19 C 51.589844 19.13 51.610156 19.260859 51.660156 19.380859 C 51.710156 19.500859 51.780859 19.609938 51.880859 19.710938 C 51.970859 19.800937 52.079219 19.869922 52.199219 19.919922 C 52.319219 19.969922 52.449844 20 52.589844 20 C 52.719844 20 52.850703 19.969922 52.970703 19.919922 C 53.090703 19.869922 53.199062 19.800937 53.289062 19.710938 C 53.479063 19.520938 53.589844 19.27 53.589844 19 C 53.589844 18.87 53.559766 18.739141 53.509766 18.619141 C 53.459766 18.489141 53.389063 18.389063 53.289062 18.289062 C 53.199063 18.199063 53.090703 18.130078 52.970703 18.080078 C 52.878203 18.040078 52.780078 18.016797 52.681641 18.007812 z M 50.085938 20.496094 C 49.830938 20.496094 49.575859 20.593563 49.380859 20.789062 C 48.990859 21.179063 48.990859 21.819938 49.380859 22.210938 C 49.570859 22.399938 49.829844 22.5 50.089844 22.5 C 50.339844 22.5 50.599063 22.399938 50.789062 22.210938 C 51.179063 21.819938 51.179062 21.179062 50.789062 20.789062 C 50.594062 20.593563 50.340937 20.496094 50.085938 20.496094 z M 47.585938 22.996094 C 47.330938 22.996094 47.075859 23.093563 46.880859 23.289062 C 46.490859 23.679063 46.490859 24.319938 46.880859 24.710938 C 47.070859 24.899938 47.329844 25 47.589844 25 C 47.839844 25 48.099063 24.899938 48.289062 24.710938 C 48.679063 24.319938 48.679062 23.679062 48.289062 23.289062 C 48.094062 23.093563 47.840937 22.996094 47.585938 22.996094 z M 45.085938 25.496094 C 44.830938 25.496094 44.575859 25.593563 44.380859 25.789062 C 43.990859 26.179063 43.990859 26.819938 44.380859 27.210938 C 44.570859 27.399938 44.829844 27.5 45.089844 27.5 C 45.339844 27.5 45.599063 27.399938 45.789062 27.210938 C 46.179063 26.819938 46.179062 26.179062 45.789062 25.789062 C 45.594062 25.593563 45.340937 25.496094 45.085938 25.496094 z M 42.486328 28.005859 C 42.388672 28.015547 42.291719 28.040078 42.199219 28.080078 C 42.079219 28.130078 41.970859 28.199062 41.880859 28.289062 C 41.790859 28.389063 41.710156 28.489141 41.660156 28.619141 C 41.610156 28.739141 41.589844 28.87 41.589844 29 C 41.589844 29.27 41.690859 29.520937 41.880859 29.710938 C 41.970859 29.800937 42.079219 29.869922 42.199219 29.919922 C 42.319219 29.969922 42.449844 30 42.589844 30 C 42.719844 30 42.850703 29.969922 42.970703 29.919922 C 43.090703 29.869922 43.199063 29.800938 43.289062 29.710938 C 43.479062 29.520937 43.589844 29.27 43.589844 29 C 43.589844 28.87 43.559766 28.739141 43.509766 28.619141 C 43.459766 28.499141 43.389062 28.389062 43.289062 28.289062 C 43.079062 28.079062 42.779297 27.976797 42.486328 28.005859 z M 40 30.001953 L 30.001953 40 L 30.708984 40.707031 L 40 49.998047 L 49.998047 40 L 40 30.001953 z M 40 32.830078 L 47.169922 40 L 40 47.169922 L 32.830078 40 L 40 32.830078 z M 37.585938 50.003906 C 37.455937 50.003906 37.324219 50.029578 37.199219 50.080078 C 37.079219 50.130078 36.970859 50.199062 36.880859 50.289062 C 36.790859 50.389062 36.710156 50.499141 36.660156 50.619141 C 36.610156 50.739141 36.589844 50.87 36.589844 51 C 36.589844 51.13 36.610156 51.260859 36.660156 51.380859 C 36.710156 51.500859 36.780859 51.609938 36.880859 51.710938 C 37.070859 51.899937 37.319844 52 37.589844 52 C 37.849844 52 38.109062 51.899938 38.289062 51.710938 C 38.389063 51.609938 38.459766 51.500859 38.509766 51.380859 C 38.559766 51.260859 38.589844 51.13 38.589844 51 C 38.589844 50.87 38.559766 50.739141 38.509766 50.619141 C 38.459766 50.489141 38.389063 50.389063 38.289062 50.289062 C 38.199063 50.199063 38.090703 50.130078 37.970703 50.080078 C 37.845703 50.029578 37.715938 50.003906 37.585938 50.003906 z M 42.414062 50.003906 C 42.284062 50.003906 42.154297 50.029578 42.029297 50.080078 C 41.909297 50.130078 41.800937 50.199063 41.710938 50.289062 C 41.520938 50.478063 41.410156 50.74 41.410156 51 C 41.410156 51.13 41.440234 51.260859 41.490234 51.380859 C 41.540234 51.500859 41.610937 51.609938 41.710938 51.710938 C 41.800938 51.800938 41.909297 51.869922 42.029297 51.919922 C 42.149297 51.969922 42.280156 52 42.410156 52 C 42.680156 52 42.929141 51.899937 43.119141 51.710938 C 43.209141 51.609938 43.289844 51.500859 43.339844 51.380859 C 43.389844 51.260859 43.410156 51.13 43.410156 51 C 43.410156 50.87 43.389844 50.739141 43.339844 50.619141 C 43.289844 50.489141 43.209141 50.389062 43.119141 50.289062 C 43.029141 50.199062 42.920781 50.130078 42.800781 50.080078 C 42.675781 50.029578 42.544063 50.003906 42.414062 50.003906 z M 35.085938 52.496094 C 34.830937 52.496094 34.575859 52.593563 34.380859 52.789062 C 33.990859 53.179063 33.990859 53.819938 34.380859 54.210938 C 34.570859 54.399938 34.829844 54.5 35.089844 54.5 C 35.339844 54.5 35.599062 54.399937 35.789062 54.210938 C 36.179063 53.819938 36.179063 53.179062 35.789062 52.789062 C 35.594062 52.593563 35.340938 52.496094 35.085938 52.496094 z M 44.914062 52.496094 C 44.659063 52.496094 44.405937 52.593563 44.210938 52.789062 C 43.820937 53.179063 43.820938 53.819938 44.210938 54.210938 C 44.400937 54.399938 44.660156 54.5 44.910156 54.5 C 45.170156 54.5 45.429141 54.399937 45.619141 54.210938 C 46.009141 53.819938 46.009141 53.179062 45.619141 52.789062 C 45.424141 52.593563 45.169062 52.496094 44.914062 52.496094 z M 32.585938 54.996094 C 32.330937 54.996094 32.075859 55.093563 31.880859 55.289062 C 31.490859 55.679063 31.490859 56.319938 31.880859 56.710938 C 32.070859 56.899938 32.329844 57 32.589844 57 C 32.839844 57 33.099062 56.899937 33.289062 56.710938 C 33.679063 56.319938 33.679063 55.679062 33.289062 55.289062 C 33.094062 55.093563 32.840938 54.996094 32.585938 54.996094 z M 47.414062 54.996094 C 47.159063 54.996094 46.905937 55.093563 46.710938 55.289062 C 46.320937 55.679063 46.320938 56.319938 46.710938 56.710938 C 46.900937 56.899938 47.160156 57 47.410156 57 C 47.670156 57 47.929141 56.899937 48.119141 56.710938 C 48.509141 56.319938 48.509141 55.679062 48.119141 55.289062 C 47.924141 55.093563 47.669062 54.996094 47.414062 54.996094 z M 30.085938 57.496094 C 29.830938 57.496094 29.575859 57.593563 29.380859 57.789062 C 28.990859 58.179063 28.990859 58.819938 29.380859 59.210938 C 29.570859 59.399938 29.829844 59.5 30.089844 59.5 C 30.339844 59.5 30.599062 59.399937 30.789062 59.210938 C 31.179063 58.819938 31.179063 58.179062 30.789062 57.789062 C 30.594062 57.593563 30.340937 57.496094 30.085938 57.496094 z M 49.914062 57.496094 C 49.659063 57.496094 49.405937 57.593563 49.210938 57.789062 C 48.820937 58.179063 48.820938 58.819938 49.210938 59.210938 C 49.400937 59.399938 49.660156 59.5 49.910156 59.5 C 50.170156 59.5 50.429141 59.399937 50.619141 59.210938 C 51.009141 58.819938 51.009141 58.179062 50.619141 57.789062 C 50.424141 57.593563 50.169062 57.496094 49.914062 57.496094 z M 27.585938 60.003906 C 27.455938 60.003906 27.324219 60.029578 27.199219 60.080078 C 27.079219 60.130078 26.970859 60.199063 26.880859 60.289062 C 26.690859 60.478063 26.589844 60.74 26.589844 61 C 26.589844 61.27 26.690859 61.520937 26.880859 61.710938 C 27.070859 61.899938 27.319844 62 27.589844 62 C 27.849844 62 28.109062 61.899937 28.289062 61.710938 C 28.479063 61.520938 28.589844 61.27 28.589844 61 C 28.589844 60.74 28.479062 60.478062 28.289062 60.289062 C 28.199063 60.199062 28.090703 60.130078 27.970703 60.080078 C 27.845703 60.029578 27.715937 60.003906 27.585938 60.003906 z M 52.316406 60.005859 C 52.21875 60.015547 52.121797 60.040078 52.029297 60.080078 C 51.909297 60.130078 51.800938 60.199062 51.710938 60.289062 C 51.520938 60.478062 51.410156 60.74 51.410156 61 C 51.410156 61.27 51.520938 61.520938 51.710938 61.710938 C 51.900938 61.899937 52.149922 62 52.419922 62 C 52.679922 62 52.929141 61.899938 53.119141 61.710938 C 53.309141 61.520937 53.410156 61.27 53.410156 61 C 53.410156 60.74 53.309141 60.478063 53.119141 60.289062 C 52.909141 60.079063 52.609375 59.976797 52.316406 60.005859 z"
        stroke="black"
        stroke-width="4"
        fill="black"
      />
    </svg>
    """
  end

  defp npm_icon(assigns) do
    ~H"""
    <svg
      xmlns="http://www.w3.org/2000/svg"
      width="16"
      height="16"
      class="w-4 h-4 mr-1"
      viewBox="0 0 16 16"
    >
      <path class="fill-black" d="M0,16V0H16V16ZM3,3V13H8V5h3v8h2V3Z" /><path
        class="fill-white"
        d="M3,3H13V13H11V5H8v8H3Z"
      />
    </svg>
    """
  end

  defp get_installation_type(params, tracker_script_configuration) do
    if params["type"] do
      params["type"]
    else
      Atom.to_string(tracker_script_configuration.installation_type)
    end
  end
end
