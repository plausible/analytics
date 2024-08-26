defmodule PlausibleWeb.Live.Installation do
  @moduledoc """
  User assistance module around Plausible installation instructions/onboarding
  """
  use PlausibleWeb, :live_view
  use Phoenix.HTML

  alias Plausible.Verification.{Checks, State}
  import PlausibleWeb.Components.Generic

  @script_config_params [
    "outbound-links",
    "tagged-events",
    "file-downloads",
    "hash",
    "pageview-props",
    "revenue"
  ]

  @installation_types [
    "GTM",
    "manual",
    "WordPress"
  ]

  @valid_qs_params @script_config_params ++ ["installation_type", "flow"]

  def script_config_params, do: @script_config_params

  def mount(
        %{"website" => domain} = params,
        %{"current_user_id" => user_id},
        socket
      ) do
    site = Plausible.Sites.get_for_user!(user_id, domain)
    flow = params["flow"]
    meta = site.installation_meta || %Plausible.Site.InstallationMeta{}

    script_config =
      @script_config_params
      |> Enum.into(%{}, &{&1, false})
      |> Map.merge(meta.script_config)
      |> Map.take(@script_config_params)

    installation_type = get_installation_type(params)

    if connected?(socket) and is_nil(installation_type) do
      Checks.run("https://#{domain}", domain,
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
       uri_params: Map.take(params, @valid_qs_params),
       site: site,
       site_created?: params["site_created"] == "true",
       flow: flow,
       installation_type: installation_type,
       initial_installation_type: installation_type,
       domain: domain,
       script_config: script_config
     )}
  end

  def handle_info({:verification_end, %State{} = state}, socket) do
    installation_type =
      case state.diagnostics do
        %{wordpress_likely?: true} -> "WordPress"
        %{gtm_likely?: true} -> "GTM"
        _ -> "manual"
      end

    {:noreply,
     assign(socket,
       initial_installation_type: installation_type,
       installation_type: installation_type
     )}
  end

  def handle_info(_msg, socket) do
    {:noreply, socket}
  end

  def render(assigns) do
    ~H"""
    <div>
      <PlausibleWeb.Components.FirstDashboardLaunchBanner.set :if={@site_created?} site={@site} />
      <PlausibleWeb.Components.FlowProgress.render flow={@flow} current_step="Install Plausible" />

      <PlausibleWeb.Components.Generic.focus_box>
        <:title :if={is_nil(@installation_type)}>
          <div class="flex w-full mx-auto justify-center">
            <PlausibleWeb.Components.Generic.spinner class="spinner block text-center h-8 w-8" />
          </div>
        </:title>
        <:title :if={@installation_type == "WordPress"}>
          Install WordPress plugin
        </:title>
        <:title :if={@installation_type == "GTM"}>
          Install Google Tag Manager
        </:title>
        <:title :if={@installation_type == "manual"}>
          Manual installation
        </:title>

        <:subtitle :if={is_nil(@installation_type)}>
          <div class="text-center">
            Determining installation type.
            <.styled_link href="#" phx-click="switch-installation-type" phx-value-method="manual">
              Skip
            </.styled_link>.
          </div>
        </:subtitle>

        <:subtitle :if={@flow == "domain_change"}>
          <p class="mb-4">
            Your domain has been changed.
            <strong>
              You must update the Plausible Installation on your site within 72 hours to guarantee continuous tracking.
            </strong>
            <br />
            <br /> If you're using the API, please also make sure to update your API credentials.
          </p>
        </:subtitle>

        <:subtitle :if={@flow == "review" and not is_nil(@installation_type)}>
          <p class="mb-4">
            Review your existing installation. You can skip this step and proceed to verifying your installation.
          </p>
        </:subtitle>

        <:subtitle :if={@installation_type == "WordPress"}>
          We've detected your website is using WordPress. Here's how to integrate Plausible:
          <ol class="list-decimal space-y-1 ml-8 mt-4">
            <li>
              <.styled_link href="https://plausible.io/wordpress-analytics-plugin" new_tab={true}>
                Install our WordPress plugin
              </.styled_link>
            </li>
            <li>After activating our plugin, click the button below to verify your installation</li>
          </ol>
        </:subtitle>
        <:subtitle :if={@installation_type == "GTM"}>
          We've detected your website is using Google Tag Manager. Here's how to integrate Plausible:
          <ol class="list-decimal space-y-1 ml-8 mt-4">
            <li>
              <.styled_link href="https://plausible.io/docs/google-tag-manager" new_tab={true}>
                Read our Google Tag Manager Guide
              </.styled_link>
            </li>
            <li>
              Use the snippet below in GTM's Custom HTML section. Once done, click the button below to verify your installation
            </li>
          </ol>
        </:subtitle>

        <:subtitle :if={@installation_type == "manual"}>
          Paste this snippet in the <code>&lt;head&gt;</code>
          of your website. You can also view
          <.styled_link href="https://plausible.io/docs/integration-guides" new_tab={true}>
            community integration guides
          </.styled_link>.
        </:subtitle>

        <div :if={@installation_type in ["manual", "GTM"]}>
          <.snippet_form
            installation_type={@installation_type}
            script_config={@script_config}
            domain={@domain}
          />
        </div>

        <.button_link
          :if={not is_nil(@installation_type)}
          href={"/#{URI.encode_www_form(@domain)}/verification?#{URI.encode_query(@uri_params)}"}
          type="submit"
          class="w-full mt-8"
        >
          <%= if @flow == "domain_change" do %>
            I understand, I'll update my website
          <% else %>
            <%= if @flow == "review" do %>
              Verify your installation
            <% else %>
              Start collecting data
            <% end %>
          <% end %>
        </.button_link>

        <:footer :if={@initial_installation_type == "WordPress" and @installation_type == "manual"}>
          <.styled_link href={} phx-click="switch-installation-type" phx-value-method="WordPress">
            Click here
          </.styled_link>
          if you prefer WordPress installation method.
        </:footer>

        <:footer :if={@initial_installation_type == "GTM" and @installation_type == "manual"}>
          <.styled_link href={} phx-click="switch-installation-type" phx-value-method="GTM">
            Click here
          </.styled_link>
          if you prefer Google Tag Manager installation method.
        </:footer>

        <:footer :if={not is_nil(@installation_type) and @installation_type != "manual"}>
          <.styled_link href={} phx-click="switch-installation-type" phx-value-method="manual">
            Click here
          </.styled_link>
          if you prefer manual installation method.
        </:footer>
      </PlausibleWeb.Components.Generic.focus_box>
    </div>
    """
  end

  defp render_snippet("manual", domain, script_config) do
    ~s|<script defer data-domain="#{domain}" src="#{tracker_url(script_config)}"></script>|
  end

  defp render_snippet("GTM", domain, script_config) do
    """
    <script>
    var script = document.createElement('script');
    script.defer = true;
    script.dataset.domain = "#{domain}";
    script.dataset.api = "https://plausible.io/api/event";
    script.src = "#{tracker_url(script_config)}";
    document.getElementsByTagName('head')[0].appendChild(script);
    </script>
    """
  end

  defp script_extension_control(assigns) do
    ~H"""
    <div class="mt-2 p-1">
      <div class="flex items-center">
        <input
          type="checkbox"
          id={"check-#{@variant}"}
          name={@variant}
          checked={@config[@variant]}
          class="block h-5 w-5 rounded dark:bg-gray-700 border-gray-300 text-indigo-600 focus:ring-indigo-600 mr-2"
        />
        <.tooltip wrapper_class="w-full z-50" class="z-50" icon?={false}>
          <label for={"check-#{@variant}"} class="border-b border-dotted border-gray-400">
            <%= @label %>
          </label>
          <:tooltip_content>
            <%= @tooltip %>
          </:tooltip_content>
        </.tooltip>
      </div>
    </div>
    """
  end

  defp snippet_form(assigns) do
    ~H"""
    <form id="snippet-form" phx-change="update-script-config">
      <textarea
        id="snippet"
        class="w-full border-1 border-gray-300 rounded-md p-4 text-gray-700"
        rows="5"
        readonly
      ><%= render_snippet(@installation_type, @domain, @script_config) %></textarea>

      <h3 class="text-normal mt-4 font-semibold">Extension options:</h3>

      <.script_extension_control
        config={@script_config}
        variant="outbound-links"
        label="Outbound links"
        tooltip="Automatically track clicks on outbound links from your website"
      />
      <.script_extension_control
        config={@script_config}
        variant="tagged-events"
        label="Tagged events"
        tooltip="Allows you to track standard custom events such as link clicks, form submits, and any other HTML element clicks"
      />
      <.script_extension_control
        config={@script_config}
        variant="file-downloads"
        label="File downloads"
        tooltip="Automatically track file downloads"
      />
      <.script_extension_control
        config={@script_config}
        variant="hash"
        label="Hash routing"
        tooltip="Automatically follow frontend navigation when using hash-based routing"
      />
      <.script_extension_control
        config={@script_config}
        variant="revenue"
        label="Revenue tracking"
        tooltip="Allows you to assign dynamic monetary values to goals and custom events to track revenue attribution"
      />
      <.script_extension_control
        config={@script_config}
        variant="pageview-props"
        label="Custom props"
        tooltip="Allow you to attach custom properties (also known as custom dimensions in Google Analytics) when sending a pageview in order to create custom metrics"
      />
    </form>
    """
  end

  def handle_event("switch-installation-type", %{"method" => method}, socket)
      when method in @installation_types do
    socket = update_uri_params(socket, %{"installation_type" => method})
    {:noreply, socket}
  end

  def handle_event("update-script-config", params, socket) do
    new_params =
      @script_config_params
      |> Enum.into(%{}, fn param ->
        {param, false}
      end)
      |> Map.merge(
        params
        |> Enum.filter(fn {key, value} -> key in @script_config_params and value == "on" end)
        |> Enum.map(fn {key, _} -> {key, true} end)
        |> Enum.into(%{})
      )

    socket = update_uri_params(socket, new_params)
    {:noreply, socket}
  end

  def handle_params(params, _uri, socket) do
    socket = do_handle_params(socket, params)
    persist_installation_meta(socket)
    {:noreply, socket}
  end

  defp do_handle_params(socket, params) when is_map(params) do
    Enum.reduce(params, socket, &param_reducer/2)
  end

  defp param_reducer({"installation_type", installation_type}, socket)
       when installation_type in @installation_types do
    assign(socket,
      installation_type: installation_type,
      uri_params: Map.put(socket.assigns.uri_params, "installation_type", installation_type)
    )
  end

  defp param_reducer({k, v}, socket)
       when k in @script_config_params do
    update_script_config(socket, k, v == "true")
  end

  defp param_reducer(_, socket) do
    socket
  end

  defp update_script_config(socket, "outbound-links" = key, true) do
    Plausible.Goals.create_outbound_links(socket.assigns.site)
    update_script_config(socket, %{key => true})
  end

  defp update_script_config(socket, "outbound-links" = key, false) do
    Plausible.Goals.delete_outbound_links(socket.assigns.site)
    update_script_config(socket, %{key => false})
  end

  defp update_script_config(socket, "file-downloads" = key, true) do
    Plausible.Goals.create_file_downloads(socket.assigns.site)
    update_script_config(socket, %{key => true})
  end

  defp update_script_config(socket, "file-downloads" = key, false) do
    Plausible.Goals.delete_file_downloads(socket.assigns.site)
    update_script_config(socket, %{key => false})
  end

  defp update_script_config(socket, key, value) do
    update_script_config(socket, %{key => value})
  end

  defp update_script_config(socket, kv) when is_map(kv) do
    new_script_config = Map.merge(socket.assigns.script_config, kv)
    assign(socket, script_config: new_script_config)
  end

  defp update_uri_params(socket, params) when is_map(params) do
    uri_params = Map.merge(socket.assigns.uri_params, params)

    socket
    |> assign(uri_params: uri_params)
    |> push_patch(
      to:
        Routes.site_path(
          socket,
          :installation,
          socket.assigns.domain,
          uri_params
        )
    )
  end

  defp get_installation_type(params) do
    Enum.find(@installation_types, &(&1 == params["installation_type"]))
  end

  defp tracker_url(script_config) do
    extensions = Enum.filter(script_config, fn {_, value} -> value end)

    tracker =
      ["script" | Enum.map(extensions, fn {key, _} -> key end)]
      |> Enum.join(".")

    "#{PlausibleWeb.Endpoint.url()}/js/#{tracker}.js"
  end

  defp persist_installation_meta(socket) do
    Plausible.Sites.update_installation_meta!(
      socket.assigns.site,
      %{
        installation_type: socket.assigns.installation_type,
        script_config: socket.assigns.script_config
      }
    )
  end
end
