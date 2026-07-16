defmodule PlausibleWeb.Live.Verification do
  @moduledoc """
  LiveView coordinating the site verification process. Rendered as a banner
  on top of the React dashboard.
  """
  use PlausibleWeb, :live_view

  alias Plausible.InstallationSupport.{State, Verification}

  @component PlausibleWeb.Live.Components.Verification
  @slowdown_for_frequent_checking :timer.seconds(0)
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

    tracker_script_configuration =
      PlausibleWeb.Tracker.get_or_create_tracker_script_configuration!(site)

    socket =
      assign(socket,
        url_to_verify: nil,
        site: site,
        super_admin?: super_admin?,
        domain: domain,
        component: @component,
        tracker_script_configuration: tracker_script_configuration,
        report_to: self(),
        delay: private[:delay] || 500,
        slowdown: private[:slowdown] || 500,
        flow: session["flow"] || "",
        checks_pid: nil,
        attempts: 0,
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
    <.live_component
      module={@component}
      installation_type={get_installation_type(@tracker_script_configuration)}
      domain={@domain}
      id="verification-standalone"
      attempts={@attempts}
      flow={@flow}
      super_admin?={@super_admin?}
      custom_url_input?={@custom_url_input?}
      tracker_script_configuration={@tracker_script_configuration}
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
          get_installation_type(socket.assigns.tracker_script_configuration),
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

    update_component(socket,
      finished?: true,
      success?: interpretation.ok?,
      interpretation: interpretation,
      verification_state: state
    )

    {:noreply, assign(socket, checks_pid: nil)}
  end

  @supported_installation_types_atoms PlausibleWeb.Tracker.supported_installation_types()
                                      |> Enum.map(&String.to_atom/1)
  defp get_installation_type(tracker_script_configuration) do
    case tracker_script_configuration.installation_type do
      type when type in @supported_installation_types_atoms ->
        Atom.to_string(type)

      _ ->
        PlausibleWeb.Tracker.fallback_installation_type()
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
end
