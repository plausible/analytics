defmodule PlausibleWeb.Live.Installation do
  @moduledoc """
  User assistance module around Plausible installation instructions/onboarding
  """
  use PlausibleWeb, :live_view
  alias Plausible.Verification.{Checks, State}

  @script_extension_params [
    "outbound-links",
    "tagged-events",
    "file-downloads",
    "hash",
    "pageview-props",
    "revenue"
  ]

  @script_config_params ["404" | @script_extension_params]

  @installation_types [
    "GTM",
    "manual",
    "WordPress"
  ]

  @valid_qs_params @script_config_params ++ ["installation_type", "flow"]

  def script_extension_params, do: @script_extension_params

  def mount(
        %{"domain" => domain} = params,
        _session,
        socket
      ) do
    site =
      Plausible.Teams.Adapter.Read.Sites.get_for_user!(socket.assigns.current_user, domain, [
        :owner,
        :admin,
        :super_admin,
        :viewer
      ])

    flow = params["flow"]
    meta = site.installation_meta || %Plausible.Site.InstallationMeta{}

    script_config =
      @script_config_params
      |> Enum.into(%{}, &{&1, false})
      |> Map.merge(meta.script_config)
      |> Map.take(@script_config_params)

    installation_type = get_installation_type(flow, meta, params)

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
      <.flash_messages flash={@flash} />
      <PlausibleWeb.Components.FirstDashboardLaunchBanner.set :if={@site_created?} site={@site} />
      <PlausibleWeb.Components.FlowProgress.render flow={@flow} current_step="Install Plausible" />

      <.focus_box>
        <:title :if={is_nil(@installation_type)}>
          <div class="flex w-full mx-auto justify-center">
            <.spinner class="spinner block text-center h-8 w-8" />
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

        <:subtitle :if={@installation_type == "WordPress"}>
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
        <:subtitle :if={@installation_type == "GTM"}>
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
      </.focus_box>
    </div>
    """
  end

  defp render_snippet("manual", domain, %{"404" => true} = script_config) do
    script_config = Map.put(script_config, "404", false)

    """
    #{render_snippet("manual", domain, script_config)}
    #{render_snippet_404()}
    """
  end

  defp render_snippet("manual", domain, script_config) do
    ~s|<script defer data-domain="#{domain}" src="#{tracker_url(script_config)}"></script>|
  end

  defp render_snippet("GTM", domain, %{"404" => true} = script_config) do
    script_config = Map.put(script_config, "404", false)

    """
    #{render_snippet("GTM", domain, script_config)}
    #{render_snippet_404("GTM")}
    """
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

  def render_snippet_404() do
    "<script>window.plausible = window.plausible || function() { (window.plausible.q = window.plausible.q || []).push(arguments) }</script>"
  end

  def render_snippet_404("GTM") do
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
          checked={@config[@variant]}
          class="block h-5 w-5 rounded dark:bg-gray-700 border-gray-300 text-indigo-600 focus:ring-indigo-600 mr-2"
        />
        <label for={"check-#{@variant}"}>
          <%= @label %>
        </label>
        <div class="ml-2 collapse md:visible">
          <.tooltip sticky?={false}>
            <:tooltip_content>
              <%= @tooltip %>
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
        ><%= render_snippet(@installation_type, @domain, @script_config) %></textarea>

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
        config={@script_config}
        variant="outbound-links"
        label="Outbound links"
        tooltip="Automatically track clicks on external links. These count towards your billable pageviews."
        learn_more="https://plausible.io/docs/outbound-link-click-tracking"
      />
      <.script_extension_control
        config={@script_config}
        variant="file-downloads"
        label="File downloads"
        tooltip="Automatically track file downloads. These count towards your billable pageviews."
        learn_more="https://plausible.io/docs/file-downloads-tracking"
      />
      <.script_extension_control
        config={@script_config}
        variant="404"
        label="404 error pages"
        tooltip="Find 404 error pages on your site. These count towards your billable pageviews. Additional action required."
        learn_more="https://plausible.io/docs/error-pages-tracking-404"
      />
      <.script_extension_control
        config={@script_config}
        variant="hash"
        label="Hashed page paths"
        tooltip="Automatically track page paths that use a # in the URL."
        learn_more="https://plausible.io/docs/hash-based-routing"
      />
      <.script_extension_control
        config={@script_config}
        variant="tagged-events"
        label="Custom events"
        tooltip="Tag site elements like buttons, links and forms to track user activity. These count towards your billable pageviews. Additional action required."
        learn_more="https://plausible.io/docs/custom-event-goals"
      />
      <.script_extension_control
        config={@script_config}
        variant="pageview-props"
        label="Custom properties"
        tooltip="Attach custom properties (also known as custom dimensions) to pageviews or custom events to create custom metrics. Additional action required."
        learn_more="https://plausible.io/docs/custom-props/introduction"
      />
      <.script_extension_control
        config={@script_config}
        variant="revenue"
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
    new_params =
      Enum.into(@script_config_params, %{}, &{&1, params[&1] == "on"})

    flash = snippet_change_flash(socket.assigns.script_config, new_params)

    socket =
      if flash do
        put_live_flash(socket, :success, flash)
      else
        socket
      end

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

  defp update_script_config(socket, "404" = key, true) do
    Plausible.Goals.create_404(socket.assigns.site)
    update_script_config(socket, %{key => true})
  end

  defp update_script_config(socket, "404" = key, false) do
    Plausible.Goals.delete_404(socket.assigns.site)
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
        ),
      replace: true
    )
  end

  @domain_change PlausibleWeb.Flows.domain_change()
  defp get_installation_type(@domain_change, meta, params) do
    meta.installation_type || get_installation_type(nil, nil, params)
  end

  defp get_installation_type(_site, _meta, params) do
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

  defp snippet_change_flash(old_config, new_config) do
    change =
      Enum.find(new_config, fn {key, _value} ->
        old_config[key] != new_config[key]
      end)

    case change do
      nil ->
        nil

      {k, false} when k in ["outbound-links", "file-downloads", "404"] ->
        "Snippet updated and goal deleted. Please insert the newest snippet into your site"

      {_, _} ->
        "Snippet updated. Please insert the newest snippet into your site"
    end
  end
end
