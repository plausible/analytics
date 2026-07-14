defmodule PlausibleWeb.Live.Verification do
  @moduledoc """
  LiveView coordinating the site verification process. Rendered as a banner
  on top of the React dashboard.
  """
  use PlausibleWeb, :live_view

  import PlausibleWeb.Components.Generic

  alias Plausible.InstallationSupport.{State, Verification}

  @component PlausibleWeb.Live.Components.Verification
  @slowdown_for_frequent_checking :timer.seconds(5)
  @use_portal? Mix.env() not in [:test, :ce_test]

  def mount(
        _params,
        %{"domain" => domain} = session,
        socket
      ) do
    current_user = socket.assigns.current_user

    site =
      Plausible.Sites.get_for_user!(current_user, domain,
        roles: [
          :owner,
          :admin,
          :editor,
          :super_admin,
          :viewer
        ]
      )

    true = Plausible.Sites.regular?(site)

    private = Map.get(socket.private.connect_info, :private, %{})

    super_admin? = Plausible.Auth.super_admin?(current_user)
    has_pageviews? = has_pageviews?(site)

    socket =
      assign(socket,
        url_to_verify: nil,
        site: site,
        super_admin?: super_admin?,
        domain: domain,
        has_pageviews?: has_pageviews?,
        component: @component,
        installation_type: get_installation_type(session["installation_type"], site),
        report_to: self(),
        delay: private[:delay] || 500,
        slowdown: private[:slowdown] || 500,
        flow: session["flow"] || "",
        checks_pid: nil,
        attempts: 0,
        polling_pageviews?: false,
        custom_url_input?: false
      )

    if connected?(socket) do
      launch_delayed(socket)
    end

    {:ok, socket}
  end

  def render(assigns) do
    assigns = assign(assigns, :use_portal?, @use_portal?)

    ~H"""
    <div id="verification-portal-container">
      <%= if @use_portal? do %>
        <.portal id="verification-portal-source" target="#verification-portal-target">
          <.verification_content {assigns} />
        </.portal>
      <% else %>
        <.verification_content {assigns} />
      <% end %>
    </div>
    """
  end

  defp verification_content(assigns) do
    ~H"""
    <.custom_url_form :if={@custom_url_input?} domain={@domain} />
    <.live_component
      :if={not @custom_url_input?}
      module={@component}
      installation_type={@installation_type}
      domain={@domain}
      id="verification-standalone"
      attempts={@attempts}
      flow={@flow}
      awaiting_first_pageview?={not @has_pageviews?}
      super_admin?={@super_admin?}
    />
    """
  end

  def handle_event("launch-verification", _, socket) do
    launch_delayed(socket)
    {:noreply, reset_component(socket)}
  end

  def handle_event("retry", _, socket) do
    launch_delayed(socket)
    {:noreply, reset_component(socket)}
  end

  def handle_event("show-custom-url-form", _, socket) do
    {:noreply, assign(socket, custom_url_input?: true)}
  end

  def handle_event("verify-custom-url", %{"custom_url" => custom_url}, socket) do
    socket =
      socket
      |> assign(url_to_verify: custom_url)
      |> assign(custom_url_input?: false)

    launch_delayed(socket)
    {:noreply, reset_component(socket)}
  end

  def handle_info({:start, report_to}, socket) do
    domain = socket.assigns.domain
    checks_pid = socket.assigns.checks_pid

    if is_pid(checks_pid) and Process.alive?(checks_pid) do
      {:noreply, socket}
    else
      case Plausible.RateLimit.check_rate(
             "site_verification:#{domain}",
             :timer.minutes(60),
             3
           ) do
        {:allow, _} -> :ok
        {:deny, _} -> :timer.sleep(@slowdown_for_frequent_checking)
      end

      {:ok, pid} =
        Verification.Checks.run(
          socket.assigns.url_to_verify,
          domain,
          socket.assigns.installation_type,
          report_to: report_to,
          slowdown: socket.assigns.slowdown
        )

      {:noreply, assign(socket, checks_pid: pid, attempts: socket.assigns.attempts + 1)}
    end
  end

  def handle_info({:check_start, {check, state}}, socket) do
    to_update = [message: check.report_progress_as()]

    to_update =
      if is_binary(state.url) do
        Keyword.put(to_update, :url_to_verify, state.url)
      else
        to_update
      end

    update_component(socket, to_update)

    {:noreply, socket}
  end

  def handle_info({:all_checks_done, %State{} = state}, socket) do
    interpretation = Verification.Checks.interpret_diagnostics(state)

    if not socket.assigns.has_pageviews? do
      schedule_pageviews_check(socket)
    end

    update_component(socket,
      finished?: true,
      success?: interpretation.ok?,
      interpretation: interpretation,
      verification_state: state
    )

    {:noreply, assign(socket, checks_pid: nil)}
  end

  def handle_info(:check_pageviews, socket) do
    if has_pageviews?(socket.assigns.site) do
      {:noreply, assign(socket, has_pageviews?: true, polling_pageviews?: false)}
    else
      socket =
        socket
        |> assign(polling_pageviews?: false)
        |> schedule_pageviews_check()

      {:noreply, socket}
    end
  end

  @supported_installation_types_atoms PlausibleWeb.Tracker.supported_installation_types()
                                      |> Enum.map(&String.to_atom/1)
  defp get_installation_type(installation_type, site) do
    cond do
      installation_type in PlausibleWeb.Tracker.supported_installation_types() ->
        installation_type

      (saved_installation_type = get_saved_installation_type(site)) in @supported_installation_types_atoms ->
        Atom.to_string(saved_installation_type)

      true ->
        PlausibleWeb.Tracker.fallback_installation_type()
    end
  end

  defp get_saved_installation_type(site) do
    case PlausibleWeb.Tracker.get_tracker_script_configuration(site) do
      %{installation_type: installation_type} ->
        installation_type

      _ ->
        nil
    end
  end

  defp schedule_pageviews_check(socket) do
    if socket.assigns.polling_pageviews? do
      socket
    else
      Process.send_after(self(), :check_pageviews, socket.assigns.delay * 2)
      assign(socket, polling_pageviews?: true)
    end
  end

  defp reset_component(socket) do
    update_component(socket,
      message: "We're visiting your site to ensure that everything is working",
      finished?: false,
      success?: false,
      diagnostics: nil
    )

    socket
  end

  defp update_component(_socket, updates) do
    send_update(
      @component,
      Keyword.merge(updates, id: "verification-standalone")
    )
  end

  defp launch_delayed(socket) do
    Process.send_after(self(), {:start, socket.assigns.report_to}, socket.assigns.delay)
  end

  defp has_pageviews?(site) do
    Plausible.Stats.Clickhouse.has_pageviews?(site)
  end

  defp custom_url_form(assigns) do
    ~H"""
    <.notice title="Enter your custom URL" theme={:gray} class="mb-4">
      <:icon>
        <Heroicons.globe_alt class="size-4.5 text-blue-600 dark:text-blue-300" />
      </:icon>
      <p class="mb-3">
        Please enter the URL where your website with the Plausible script is located.
      </p>
      <form phx-submit="verify-custom-url" class="flex flex-wrap items-center gap-2">
        <label for="custom_url" class="sr-only">Website URL</label>
        <input
          type="url"
          name="custom_url"
          id="custom_url"
          required
          class="flex-1 min-w-64 px-3 py-1.5 border border-gray-300 dark:border-gray-600 rounded-md shadow-xs text-sm focus:outline-hidden focus:ring-indigo-500 focus:border-indigo-500 dark:bg-gray-800 dark:text-white"
          placeholder={"https://#{@domain}"}
          value={"https://#{@domain}"}
        />
        <button
          type="submit"
          class="px-3 py-1.5 rounded-md shadow-xs text-sm font-medium text-white bg-indigo-600 hover:bg-indigo-700 focus:outline-hidden focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500 dark:bg-indigo-500 dark:hover:bg-indigo-600"
        >
          Verify Installation
        </button>
      </form>
    </.notice>
    """
  end
end
