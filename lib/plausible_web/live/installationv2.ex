defmodule PlausibleWeb.Live.InstallationV2 do
  @moduledoc """
  User assistance module around Plausible installation instructions/onboarding
  """

  use Plausible
  use PlausibleWeb, :live_view

  require Logger

  alias PlausibleWeb.Flows
  alias Phoenix.LiveView.AsyncResult
  alias PlausibleWeb.Live.InstallationV2.Icons
  alias PlausibleWeb.Live.InstallationV2.Instructions

  on_ee do
    alias Plausible.InstallationSupport.{Detection, Result}

    @installation_methods ["manual", "wordpress", "gtm", "npm"]
  else
    @installation_methods ["manual", "wordpress", "npm"]
  end

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
        # site scan - we just default the pre-selected tab to "manual".

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

    {:ok,
     assign(socket,
       site: site,
       flow: flow
     )}
  end

  def handle_params(params, _url, socket) do
    socket =
      if connected?(socket) && socket.assigns.recommended_installation_type.result &&
           params["type"] in @installation_methods do
        assign(socket,
          installation_type: %AsyncResult{result: params["type"]}
        )
      else
        socket
      end

    {:noreply, socket}
  end

  def render(assigns) do
    ~H"""
    <div>
      <PlausibleWeb.Components.FlowProgress.render flow={@flow} current_step="Install Plausible" />

      <.focus_box>
        <.async_result :let={recommended_installation_type} assign={@recommended_installation_type}>
          <:loading>
            <div class="text-center text-gray-500">
              {if(@flow == Flows.review(),
                do: "Scanning your site to detect how Plausible is integrated...",
                else: "Determining the simplest integration path for your website..."
              )}
            </div>
            <div class="flex items-center justify-center py-8">
              <.spinner class="w-6 h-6" />
            </div>
          </:loading>

          <div class="flex flex-row gap-2 bg-gray-100 dark:bg-gray-900 rounded-md p-1">
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
              <.tab patch={"?type=gtm&flow=#{@flow}"} selected={@installation_type.result == "gtm"}>
                <Icons.tag_manager_icon /> Tag Manager
              </.tab>
            <% end %>
            <.tab patch={"?type=npm&flow=#{@flow}"} selected={@installation_type.result == "npm"}>
              <Icons.npm_icon /> NPM
            </.tab>
          </div>

          <%= on_ee do %>
            <.outdated_script_notice
              :if={@v1_detected.result == true}
              recommended_installation_type={@recommended_installation_type}
              installation_type={@installation_type}
            />
          <% end %>

          <.form for={@tracker_script_configuration_form.result} phx-submit="submit" class="mt-4">
            <.input
              type="hidden"
              field={@tracker_script_configuration_form.result[:installation_type]}
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

            <.button type="submit" class="w-full mt-8">
              {verify_cta(@installation_type.result)}
            </.button>
          </.form>
        </.async_result>
        <:footer :if={ce?() and @installation_type.result == "manual"}>
          <.focus_list>
            <:item>
              Still using the legacy snippet with the data-domain attribute? See
              <.styled_link href="https://plausible.io/docs/script-update-guide">
                migration guide
              </.styled_link>
            </:item>
          </.focus_list>
        </:footer>
      </.focus_box>
    </div>
    """
  end

  defp verify_cta("manual"), do: "Verify Script installation"
  defp verify_cta("wordpress"), do: "Verify WordPress installation"
  defp verify_cta("gtm"), do: "Verify Tag Manager installation"
  defp verify_cta("npm"), do: "Verify NPM installation"

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
        _ -> {"manual", false}
      end
    end
  else
    defp detect_recommended_installation_type(_flow, _site) do
      {"manual", false}
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

  attr :selected, :boolean, default: false
  attr :patch, :string, required: true
  slot :inner_block, required: true

  defp tab(assigns) do
    assigns =
      if assigns[:selected] do
        assign(assigns,
          class:
            "bg-white dark:bg-gray-800 rounded-md px-3.5 py-2.5 text-sm font-medium flex items-center flex-1 justify-center whitespace-nowrap"
        )
      else
        assign(assigns,
          class:
            "bg-gray-100 dark:bg-gray-700 rounded-md px-3.5 py-2.5 text-sm font-medium flex items-center cursor-pointer flex-1 justify-center whitespace-nowrap"
        )
      end

    ~H"""
    <.link patch={@patch} class={@class}>
      {render_slot(@inner_block)}
    </.link>
    """
  end

  def handle_event("submit", %{"tracker_script_configuration" => params}, socket) do
    PlausibleWeb.Tracker.update_script_configuration!(
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
        params["type"] in @installation_methods ->
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
