defmodule PlausibleWeb.Live.Installation do
  @moduledoc """
  User assistance module around Plausible installation instructions/onboarding
  """

  use Plausible
  use PlausibleWeb, :live_view

  alias PlausibleWeb.{Flows, Layouts}
  alias Phoenix.LiveView.AsyncResult
  alias PlausibleWeb.Live.Installation.Icons
  alias PlausibleWeb.Live.Installation.Instructions

  @submit_button_text "I've installed it"

  on_ee do
    alias Plausible.InstallationSupport.{Detection, Result}
  end

  def mount(
        %{"domain" => domain} = params,
        _session,
        socket
      ) do
    site =
      Plausible.Sites.get_for_user!(socket.assigns.current_user, domain,
        roles: [
          :owner,
          :admin,
          :editor,
          :super_admin,
          :viewer
        ]
      )

    flow = params["flow"] || Flows.provisioning()

    socket =
      on_ee do
        if connected?(socket) do
          assign_async(
            socket,
            [
              :recommended_installation_type,
              :installation_type,
              :tracker_script_configuration_form,
              :v1_detected
            ],
            fn -> initialize_installation_data(flow, site, params) end
          )
        else
          assign_loading_states(socket)
        end
      else
        # On Community Edition, there's no v1 detection, nor pre-installation
        # site scan - we just default the preselected tab to "manual".

        # Although it's functionally unnecessary, we stick to using `%AsyncResult{}`
        # for these assigns to minimize branching out the CE code and maintain only
        # a single `render` function.

        {:ok, installation_data} = initialize_installation_data(flow, site, params)

        assign(socket,
          recommended_installation_type: %AsyncResult{
            result: installation_data.recommended_installation_type,
            ok?: true
          },
          installation_type: %AsyncResult{
            result: installation_data.installation_type,
            ok?: true
          },
          tracker_script_configuration_form: %AsyncResult{
            result: installation_data.tracker_script_configuration_form,
            ok?: true
          },
          v1_detected: %AsyncResult{
            result: installation_data.v1_detected,
            ok?: true
          }
        )
      end

    {heading, subtitle} =
      if flow == Flows.review() do
        {"Review installation", "See how to install Plausible on your site."}
      else
        {"Add tracking to your site", "Install Plausible on #{site.domain} to start seeing data."}
      end

    {:ok,
     assign(socket,
       site: site,
       flow: flow,
       return_to: params["return_to"],
       heading: heading,
       subtitle: subtitle
     )}
  end

  def handle_params(params, _url, socket) do
    socket =
      if connected?(socket) && socket.assigns.recommended_installation_type.result &&
           params["type"] in PlausibleWeb.Tracker.supported_installation_types() do
        assign(socket,
          installation_type: %AsyncResult{result: params["type"]}
        )
      else
        socket
      end

    {:noreply, socket}
  end

  def render(assigns) do
    assigns = assign(assigns, :submit_button_text, @submit_button_text)

    ~H"""
    <.onboarding_or_app_layout {assigns}>
      <PlausibleWeb.Components.Site.NewSiteForm.heading_and_subtitle
        heading={@heading}
        subtitle={@subtitle}
      />
      <div class="flex flex-col gap-10 w-full max-w-md mx-auto mt-10 pb-16 px-4 text-gray-900 dark:text-gray-100">
        <.async_result :let={recommended_installation_type} assign={@recommended_installation_type}>
          <:loading>
            <div class="flex gap-3 items-center">
              <.spinner class="size-5" />
              <div class="text-gray-500 dark:text-gray-400 text-base">
                {if(@flow == Flows.review(),
                  do: "Checking how Plausible is integrated into your site...",
                  else: "Checking how your site is built..."
                )}
              </div>
            </div>
          </:loading>

          <div class="flex flex-col gap-3">
            <label class="text-sm font-semibold text-gray-800 dark:text-gray-200">
              Installation method
            </label>
            <div class="grid grid-cols-2 sm:flex sm:flex-row gap-1.5">
              <.tab
                patch={"?type=manual&flow=#{@flow}"}
                selected={@installation_type.result == "manual"}
              >
                <Icons.script_icon /> Script
              </.tab>
              <.tab
                patch={"?type=wordpress&flow=#{@flow}"}
                selected={@installation_type.result == "wordpress"}
              >
                <Icons.wordpress_icon /> WordPress
              </.tab>
              <%= on_ee do %>
                <.tab
                  patch={"?type=gtm&flow=#{@flow}"}
                  selected={@installation_type.result == "gtm"}
                >
                  <Icons.tag_manager_icon /> Tag Manager
                </.tab>
              <% end %>
              <.tab patch={"?type=npm&flow=#{@flow}"} selected={@installation_type.result == "npm"}>
                <Icons.npm_icon /> NPM
              </.tab>
            </div>
          </div>

          <%= on_ee do %>
            <.outdated_script_notice
              :if={@v1_detected.result == true}
              recommended_installation_type={@recommended_installation_type}
              installation_type={@installation_type}
            />
          <% end %>

          <.form
            class="flex flex-col gap-10"
            for={@tracker_script_configuration_form.result}
            phx-submit="submit"
            onsubmit={install_method_event(@installation_type.result, recommended_installation_type)}
          >
            <input
              type="hidden"
              name={@tracker_script_configuration_form.result[:installation_type].name}
              value={@installation_type.result}
            />
            <Instructions.manual_instructions
              :if={@installation_type.result == "manual"}
              tracker_script_configuration_form={@tracker_script_configuration_form.result}
            />

            <Instructions.wordpress_instructions
              :if={@installation_type.result == "wordpress"}
              flow={@flow}
              recommended_installation_type={recommended_installation_type}
            />
            <%= on_ee do %>
              <Instructions.gtm_instructions
                :if={@installation_type.result == "gtm"}
                recommended_installation_type={recommended_installation_type}
                tracker_script_configuration_form={@tracker_script_configuration_form.result}
              />
            <% end %>
            <Instructions.npm_instructions :if={@installation_type.result == "npm"} />

            <div class="flex justify-end items-center gap-x-2">
              <.secondary_action flow={@flow} return_to={@return_to} domain={@site.domain} />
              <.button
                type="submit"
                mt?={false}
                class={
                  install_method_event(
                    @installation_type.result,
                    recommended_installation_type
                  )
                }
              >
                {@submit_button_text}
              </.button>
            </div>
          </.form>
        </.async_result>

        <div
          :if={ce?() and @installation_type.result == "manual"}
          class="mt-8 pt-6 border-t border-gray-200 dark:border-gray-700 text-sm"
        >
          <.focus_list>
            <:item>
              Still using the legacy snippet with the data-domain attribute? See
              <.styled_link href="https://plausible.io/docs/script-update-guide">
                migration guide
              </.styled_link>
            </:item>
          </.focus_list>
        </div>
      </div>
    </.onboarding_or_app_layout>
    """
  end

  on_ee do
    defp install_method_event(installation_type, recommended) do
      method = installation_method_label(installation_type)
      match = if installation_type == recommended, do: "true", else: "false"

      opts =
        Jason.encode!(%{
          "props" => %{
            "method" => method,
            "recommended_match" => match
          }
        })

      "window.plausible('Site installation method', #{opts})"
    end

    defp installation_method_label("manual"), do: "script"
    defp installation_method_label(other), do: other
  else
    defp install_method_event(_, _), do: ""
  end

  on_ee do
    defp detect_recommended_installation_type(flow, site) do
      with {:ok, detection_result} <-
             Detection.Checks.run_with_rate_limit(nil, site.domain,
               detect_v1?: flow == Flows.review(),
               report_to: nil,
               slowdown: 0,
               async?: false
             ),
           %Result{ok?: true, data: data} <-
             Detection.Checks.interpret_diagnostics(detection_result) do
        {data.suggested_technology, data.v1_detected}
      else
        _ -> {PlausibleWeb.Tracker.fallback_installation_type(), false}
      end
    end
  else
    defp detect_recommended_installation_type(_flow, _site) do
      {PlausibleWeb.Tracker.fallback_installation_type(), false}
    end
  end

  on_ee do
    defp outdated_script_notice(assigns) do
      ~H"""
      <div :if={
        @recommended_installation_type.result == "manual" and
          @installation_type.result == "manual"
      }>
        <.notice class="mt-4" theme={:yellow}>
          Your website is running an outdated version of the tracking script. Please
          <.styled_link new_tab href="https://plausible.io/docs/script-update-guide">
            update
          </.styled_link>
          your tracking script before continuing
        </.notice>
      </div>

      <div :if={
        @recommended_installation_type.result == "gtm" and
          @installation_type.result == "gtm"
      }>
        <.notice class="mt-4" theme={:yellow}>
          Your website might be using an outdated version of our Google Tag Manager template.
          If so,
          <.styled_link new_tab href="https://plausible.io/docs/script-update-guide#gtm">
            update
          </.styled_link>
          your Google Tag Manager template before continuing
        </.notice>
      </div>
      """
    end

    defp assign_loading_states(socket) do
      assign(socket,
        recommended_installation_type: AsyncResult.loading(),
        v1_detected: AsyncResult.loading(),
        installation_type: AsyncResult.loading(),
        tracker_script_configuration_form: AsyncResult.loading()
      )
    end
  end

  defp onboarding_or_app_layout(assigns) do
    if assigns.flow == Flows.register() do
      ~H"""
      <Layouts.onboarding
        current_step={Flows.installation_step()}
        current_user={@current_user}
        flash={@flash}
      >
        {render_slot(@inner_block)}
      </Layouts.onboarding>
      """
    else
      ~H"""
      <Layouts.app
        footer?={false}
        current_user={@current_user}
        current_team={@current_team}
        current_team_role={@current_team_role}
        teams={@teams}
        my_team={@my_team}
        flash={@flash}
      >
        {render_slot(@inner_block)}
      </Layouts.app>
      """
    end
  end

  attr :flow, :string, required: true
  attr :return_to, :string, default: nil
  attr :domain, :string, required: true

  defp secondary_action(assigns) do
    {label, href} =
      cond do
        assigns.return_to == "dashboard" ->
          {"Back to dashboard",
           Routes.stats_path(PlausibleWeb.Endpoint, :stats, assigns.domain,
             verify_installation: true,
             flow: assigns.flow
           )}

        assigns.flow == Flows.review() ->
          {"Back to settings",
           Routes.site_path(PlausibleWeb.Endpoint, :settings_general, assigns.domain)}

        assigns.flow == Flows.provisioning() ->
          {"Back to sites", Routes.site_path(PlausibleWeb.Endpoint, :index)}

        true ->
          {"Skip", Routes.site_path(PlausibleWeb.Endpoint, :index)}
      end

    assigns = assign(assigns, label: label, href: href)

    ~H"""
    <.button_link theme="ghost" href={@href} mt?={false}>
      {@label}
    </.button_link>
    """
  end

  attr :selected, :boolean, default: false
  attr :patch, :string, required: true
  slot :inner_block, required: true

  defp tab(assigns) do
    base_classes =
      "rounded-md border px-2.5 py-1.5 text-sm font-medium flex items-center gap-1 flex-1 justify-center whitespace-nowrap transition-colors duration-150"

    selected_class =
      if assigns[:selected] do
        "bg-indigo-50/80 dark:bg-indigo-900/30 border-indigo-500 text-gray-900 dark:text-gray-100"
      else
        "bg-transparent border-gray-200 dark:border-gray-700 text-gray-700 dark:text-gray-300 hover:border-gray-300 dark:hover:border-gray-600 cursor-pointer"
      end

    assigns = assign(assigns, class: "#{selected_class} #{base_classes}")

    ~H"""
    <.link patch={@patch} class={@class}>
      {render_slot(@inner_block)}
    </.link>
    """
  end

  def handle_event("submit", %{"tracker_script_configuration" => params}, socket) do
    PlausibleWeb.Tracker.update_script_configuration!(socket.assigns.site, params, :installation)

    domain = socket.assigns.site.domain

    destination =
      on_ee do
        Routes.stats_path(socket, :stats, domain,
          verify_installation: true,
          flow: socket.assigns.flow
        )
      else
        Routes.stats_path(socket, :stats, domain, [])
      end

    {:noreply, redirect(socket, to: destination)}
  end

  defp initialize_installation_data(flow, site, params) do
    {recommended_installation_type, v1_detected} =
      detect_recommended_installation_type(flow, site)

    tracker_script_configuration =
      PlausibleWeb.Tracker.get_or_create_tracker_script_configuration!(site, %{
        outbound_links: true,
        form_submissions: true,
        file_downloads: true,
        track_404_pages: true,
        installation_type: recommended_installation_type
      })

    selected_installation_type =
      cond do
        params["type"] in PlausibleWeb.Tracker.supported_installation_types() ->
          params["type"]

        flow == Flows.review() and
            not is_nil(tracker_script_configuration.installation_type) ->
          Atom.to_string(tracker_script_configuration.installation_type)

        true ->
          recommended_installation_type
      end

    {:ok,
     %{
       recommended_installation_type: recommended_installation_type,
       v1_detected: v1_detected,
       installation_type: selected_installation_type,
       tracker_script_configuration_form:
         to_form(
           Plausible.Site.TrackerScriptConfiguration.installation_changeset(
             tracker_script_configuration,
             %{}
           )
         )
     }}
  end
end
