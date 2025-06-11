defmodule PlausibleWeb.Live.Installation do
  @moduledoc """
  User assistance module around Plausible installation instructions/onboarding
  """
  use PlausibleWeb, :live_view
  alias Plausible.Verification.{Checks, State}

  @script_extension_params %{
    "outbound_links" => "outbound-links",
    "tagged_events" => "tagged-events",
    "file_downloads" => "file-downloads",
    "hash_based_routing" => "hash",
    "pageview_props" => "pageview-props",
    "revenue_tracking" => "revenue"
  }

  @script_config_params ["track_404_pages" | Map.keys(@script_extension_params)]

  @installation_types [
    "gtm",
    "manual",
    "wordpress"
  ]

  @valid_qs_params @script_config_params ++ ["installation_type", "flow"]

  def script_extension_params, do: @script_extension_params

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

    if FunWithFlags.enabled?(:scriptv2, for: site) do
      {:ok, redirect(socket, to: "/#{domain}/installationv2?flow=#{params["flow"]}")}
    else
      flow = params["flow"]

      tracker_script_configuration =
        PlausibleWeb.Tracker.get_or_create_tracker_script_configuration!(site)

      installation_type = get_installation_type(flow, tracker_script_configuration, params)

      config =
        Map.new(@script_config_params, fn key ->
          string_key = String.to_existing_atom(key)
          {key, Map.get(tracker_script_configuration, string_key)}
        end)

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
         connected?: connected?(socket),
         site: site,
         site_created?: params["site_created"] == "true",
         flow: flow,
         installation_type: installation_type,
         initial_installation_type: installation_type,
         domain: domain,
         config: config
       )}
    end
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
      <.flash_messages flash={@flash} />
      <PlausibleWeb.Components.FirstDashboardLaunchBanner.set :if={@site_created?} site={@site} />
      <PlausibleWeb.Components.FlowProgress.render flow={@flow} current_step="Install Plausible" />

      <.focus_box>
        <:title :if={is_nil(@installation_type)}>
          <div class="flex w-full mx-auto justify-center">
            <.spinner class="spinner block text-center h-8 w-8" />
          </div>
        </:title>
        <:title :if={@installation_type == "wordpress"}>
          Install WordPress plugin
        </:title>
        <:title :if={@installation_type == "gtm"}>
          Install Google Tag Manager
        </:title>
        <:title :if={@installation_type == "manual"}>
          Manual installation
        </:title>

        <:subtitle :if={is_nil(@installation_type)}>
          <div class="text-center mt-8">
            Determining installation type...
            <.styled_link
              :if={@connected?}
              href="#"
              phx-click="switch-installation-type"
              phx-value-method="manual"
            >
              Skip
            </.styled_link>
          </div>
        </:subtitle>

        <:subtitle :if={@flow == PlausibleWeb.Flows.domain_change()}>
          <p class="mb-4">
            Your domain has been changed.
            <strong>
              You must update the Plausible Installation on your site within 72 hours to guarantee continuous tracking.
            </strong>
            <br />
            <br /> If you're using the API, please also make sure to update your API credentials.
          </p>
        </:subtitle>

        <:subtitle :if={@flow == PlausibleWeb.Flows.review() and not is_nil(@installation_type)}>
          <p class="mb-4">
            Review your existing installation. You can skip this step and proceed to verifying your installation.
          </p>
        </:subtitle>

        <:subtitle :if={@installation_type == "wordpress"}>
          We've detected your website is using WordPress. Here's how to integrate Plausible:
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
        </:subtitle>
        <:subtitle :if={@installation_type == "gtm"}>
          We've detected your website is using Google Tag Manager. Here's how to integrate Plausible:
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
        </:subtitle>

        <:subtitle :if={@installation_type == "manual"}>
          Paste this snippet into the <code>&lt;head&gt;</code>
          section of your site. See our
          <.styled_link href="https://plausible.io/docs/integration-guides" new_tab={true}>
            installation guides.
          </.styled_link>
          Once done, click the button below to verify your installation.
        </:subtitle>

        <div :if={@installation_type in ["manual", "gtm"]}>
          <.snippet_form installation_type={@installation_type} config={@config} domain={@domain} />
        </div>

        <.button_link
          :if={not is_nil(@installation_type)}
          href={"/#{URI.encode_www_form(@domain)}/verification?#{URI.encode_query(@uri_params)}"}
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

        <:footer :if={@initial_installation_type == "wordpress" and @installation_type == "manual"}>
          <.styled_link href={} phx-click="switch-installation-type" phx-value-method="wordpress">
            Click here
          </.styled_link>
          if you prefer WordPress installation method.
        </:footer>

        <:footer :if={
          (@initial_installation_type == "gtm" and @installation_type == "manual") or
            (@initial_installation_type == "manual" and @installation_type == "manual")
        }>
          <.styled_link href={} phx-click="switch-installation-type" phx-value-method="gtm">
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
      </.focus_box>
    </div>
    """
  end

  defp render_snippet("manual", domain, %{"track_404_pages" => true} = script_config) do
    script_config = Map.put(script_config, "track_404_pages", false)

    """
    #{render_snippet("manual", domain, script_config)}
    #{render_snippet_404()}
    """
  end

  defp render_snippet("manual", domain, script_config) do
    ~s|<script defer data-domain="#{domain}" src="#{tracker_url(script_config)}"></script>|
  end

  defp render_snippet("gtm", domain, %{"track_404_pages" => true} = script_config) do
    script_config = Map.put(script_config, "track_404_pages", false)

    """
    #{render_snippet("gtm", domain, script_config)}
    #{render_snippet_404("gtm")}
    """
  end

  defp render_snippet("gtm", domain, script_config) do
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

  def render_snippet_404() do
    "<script>window.plausible = window.plausible || function() { (window.plausible.q = window.plausible.q || []).push(arguments) }</script>"
  end

  def render_snippet_404("gtm") do
    render_snippet_404()
  end

  defp script_extension_control(assigns) do
    ~H"""
    <div class="mt-2 p-1 text-sm">
      <div class="flex items-center">
        <input
          type="checkbox"
          id={"check-#{@variant}"}
          name={@variant}
          checked={Map.get(@config, @variant, false)}
          class="block h-5 w-5 rounded dark:bg-gray-700 border-gray-300 text-indigo-600 focus:ring-indigo-600 mr-2"
        />
        <label for={"check-#{@variant}"}>
          {@label}
        </label>
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

  defp snippet_form(assigns) do
    ~H"""
    <form id="snippet-form" phx-change="update-script-config">
      <div class="relative">
        <textarea
          id="snippet"
          class="w-full border-1 border-gray-300 rounded-md p-4 text-sm text-gray-700 dark:border-gray-500 dark:bg-gray-900 dark:text-gray-300"
          rows="5"
          readonly
        ><%= render_snippet(@installation_type, @domain, @config) %></textarea>

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

      <.h2 class="mt-8 text-sm font-medium">Enable optional measurements:</.h2>
      <.script_extension_control
        config={@config}
        variant="outbound_links"
        label="Outbound links"
        tooltip="Automatically track clicks on external links. These count towards your billable pageviews."
        learn_more="https://plausible.io/docs/outbound-link-click-tracking"
      />
      <.script_extension_control
        config={@config}
        variant="file_downloads"
        label="File downloads"
        tooltip="Automatically track file downloads. These count towards your billable pageviews."
        learn_more="https://plausible.io/docs/file-downloads-tracking"
      />
      <.script_extension_control
        config={@config}
        variant="track_404_pages"
        label="404 error pages"
        tooltip="Find 404 error pages on your site. These count towards your billable pageviews. Additional action required."
        learn_more="https://plausible.io/docs/error-pages-tracking-404"
      />
      <.script_extension_control
        config={@config}
        variant="hash_based_routing"
        label="Hashed page paths"
        tooltip="Automatically track page paths that use a # in the URL."
        learn_more="https://plausible.io/docs/hash-based-routing"
      />
      <.script_extension_control
        config={@config}
        variant="tagged_events"
        label="Custom events"
        tooltip="Tag site elements like buttons, links and forms to track user activity. These count towards your billable pageviews. Additional action required."
        learn_more="https://plausible.io/docs/custom-event-goals"
      />
      <.script_extension_control
        config={@config}
        variant="pageview_props"
        label="Custom properties"
        tooltip="Attach custom properties (also known as custom dimensions) to pageviews or custom events to create custom metrics. Additional action required."
        learn_more="https://plausible.io/docs/custom-props/introduction"
      />
      <.script_extension_control
        config={@config}
        variant="revenue_tracking"
        label="Ecommerce revenue"
        tooltip="Assign monetary values to purchases and track revenue attribution. Additional action required."
        learn_more="https://plausible.io/docs/ecommerce-revenue-tracking"
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
    new_config =
      @script_config_params
      |> Map.new(fn key -> {key, Map.get(params, key) == "on"} end)

    flash = snippet_change_flash(socket.assigns.config, new_config)

    socket =
      if flash do
        put_live_flash(socket, :success, flash)
      else
        socket
      end

    socket = update_uri_params(socket, new_config)
    {:noreply, socket}
  end

  def handle_params(params, _uri, socket) do
    socket =
      socket
      |> update_installation_type(params)
      |> update_script_config(params)
      |> persist_tracker_script_configuration()

    {:noreply, socket}
  end

  defp update_installation_type(socket, %{"installation_type" => installation_type})
       when installation_type in @installation_types do
    assign(socket,
      installation_type: installation_type,
      uri_params: Map.put(socket.assigns.uri_params, "installation_type", installation_type)
    )
  end

  defp update_installation_type(socket, _params), do: socket

  defp update_script_config(socket, params) do
    configuration_update =
      @script_config_params
      |> Enum.filter(&Map.has_key?(params, &1))
      |> Map.new(fn key -> {key, Map.get(params, key) == "true"} end)

    assign(socket,
      config: Map.merge(socket.assigns.config, configuration_update)
    )
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
        ),
      replace: true
    )
  end

  @domain_change PlausibleWeb.Flows.domain_change()
  defp get_installation_type(@domain_change, tracker_script_configuration, params) do
    case tracker_script_configuration.installation_type do
      nil ->
        get_installation_type(nil, nil, params)

      installation_type ->
        Atom.to_string(installation_type)
    end
  end

  defp get_installation_type(_type, _tracker_script_configuration, params) do
    Enum.find(@installation_types, &(&1 == params["installation_type"]))
  end

  defp tracker_url(script_config) do
    extensions =
      @script_extension_params
      |> Enum.flat_map(fn {key, extension} ->
        if(Map.get(script_config, key), do: [extension], else: [])
      end)

    tracker = Enum.join(["script" | extensions], ".")

    "#{PlausibleWeb.Endpoint.url()}/js/#{tracker}.js"
  end

  defp persist_tracker_script_configuration(socket) do
    tracker_script_config_update =
      Map.merge(socket.assigns.config, %{
        "site_id" => socket.assigns.site.id,
        "installation_type" => socket.assigns.installation_type
      })

    PlausibleWeb.Tracker.update_script_configuration(
      socket.assigns.site,
      tracker_script_config_update,
      :installation
    )

    socket
  end

  defp snippet_change_flash(old_config, new_config) do
    change =
      Enum.find(new_config, fn {key, new_value} ->
        Map.get(old_config, key) != new_value
      end)

    case change do
      nil ->
        nil

      {k, false} when k in ["outbound_links", "file_downloads", "track_404_pages"] ->
        "Snippet updated and goal deleted. Please insert the newest snippet into your site"

      {_, _} ->
        "Snippet updated. Please insert the newest snippet into your site"
    end
  end
end
