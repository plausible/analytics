defmodule PlausibleWeb.Live.Verification do
  @moduledoc """
  LiveView coordinating the site verification process.
  Onboarding new sites, renders a standalone component.
  Embedded modal variant is available for general site settings.
  """
  use Plausible
  use PlausibleWeb, :live_view

  alias Plausible.Verification.{Checks, State}

  @component PlausibleWeb.Live.Components.Verification
  @slowdown_for_frequent_checking :timer.seconds(5)

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

    private = Map.get(socket.private.connect_info, :private, %{})

    super_admin? = Plausible.Auth.is_super_admin?(socket.assigns.current_user)
    has_pageviews? = has_pageviews?(site)

    socket =
      assign(socket,
        site: site,
        super_admin?: super_admin?,
        domain: domain,
        has_pageviews?: has_pageviews?,
        component: @component,
        installation_type: params["installation_type"],
        report_to: self(),
        delay: private[:delay] || 500,
        slowdown: private[:slowdown] || 500,
        flow: params["flow"] || "",
        checks_pid: nil,
        attempts: 0
      )

    on_ee do
      if connected?(socket) do
        launch_delayed(socket)
      end
    end

    on_ee do
      {:ok, socket}
    else
      # on CE we skip the verification process and instead,
      # we just wait for the first pageview to be recorded
      socket =
        if has_pageviews? do
          redirect_to_stats(socket)
        else
          schedule_pageviews_check(socket)
        end

      {:ok, socket}
    end
  end

  on_ee do
    def render(assigns) do
      ~H"""
      <PlausibleWeb.Components.FlowProgress.render flow={@flow} current_step="Verify installation" />

      <.live_component
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
  else
    def render(assigns) do
      ~H"""
      <PlausibleWeb.Components.FlowProgress.render flow={@flow} current_step="Verify installation" />
      <.awaiting_pageviews />
      """
    end
  end

  on_ce do
    defp awaiting_pageviews(assigns) do
      ~H"""
      <.focus_box>
        <div class="flex items-center">
          <div class="block pulsating-circle"></div>
          <p class="ml-8">Awaiting your first pageview …</p>
        </div>
      </.focus_box>
      """
    end
  end

  def handle_event("launch-verification", _, socket) do
    launch_delayed(socket)
    {:noreply, reset_component(socket)}
  end

  def handle_event("retry", _, socket) do
    launch_delayed(socket)
    {:noreply, reset_component(socket)}
  end

  def handle_info({:start, report_to}, socket) do
    if is_pid(socket.assigns.checks_pid) and Process.alive?(socket.assigns.checks_pid) do
      {:noreply, socket}
    else
      case Plausible.RateLimit.check_rate(
             "site_verification_#{socket.assigns.domain}",
             :timer.minutes(60),
             3
           ) do
        {:allow, _} -> :ok
        {:deny, _} -> :timer.sleep(@slowdown_for_frequent_checking)
      end

      {:ok, pid} =
        Checks.run(
          "https://#{socket.assigns.domain}",
          socket.assigns.domain,
          report_to: report_to,
          slowdown: socket.assigns.slowdown
        )

      {:noreply, assign(socket, checks_pid: pid, attempts: socket.assigns.attempts + 1)}
    end
  end

  def handle_info({:verification_check_start, {check, _state}}, socket) do
    update_component(socket,
      message: check.report_progress_as()
    )

    {:noreply, socket}
  end

  def handle_info({:verification_end, %State{} = state}, socket) do
    interpretation = Checks.interpret_diagnostics(state)

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
    socket =
      if has_pageviews?(socket.assigns.site) do
        redirect_to_stats(socket)
      else
        schedule_pageviews_check(socket)
      end

    {:noreply, socket}
  end

  defp schedule_pageviews_check(socket) do
    Process.send_after(self(), :check_pageviews, socket.assigns.delay * 2)
    socket
  end

  defp redirect_to_stats(socket) do
    stats_url = Routes.stats_url(PlausibleWeb.Endpoint, :stats, socket.assigns.domain, [])
    redirect(socket, external: stats_url)
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
end
