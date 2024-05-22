defmodule PlausibleWeb.Live.Verification do
  @moduledoc """
  LiveView coordinating the site verification process.
  Onboarding new sites, renders a standalone component. 
  Embedded modal variant is available for general site settings.
  """
  use PlausibleWeb, :live_view
  use Phoenix.HTML

  alias Plausible.Verification.{Checks, State}
  alias PlausibleWeb.Live.Components.Modal

  @component PlausibleWeb.Live.Components.Verification
  @slowdown_for_frequent_checking :timer.seconds(5)

  def mount(
        :not_mounted_at_router,
        %{"domain" => domain} = session,
        socket
      ) do
    socket =
      assign(socket,
        domain: domain,
        modal?: !!session["modal?"],
        component: @component,
        report_to: session["report_to"] || self(),
        delay: session["slowdown"] || 500,
        slowdown: session["slowdown"] || 500,
        checks_pid: nil,
        attempts: 0
      )

    if connected?(socket) and !session["modal?"] do
      launch_delayed(socket)
    end

    {:ok, socket}
  end

  def render(assigns) do
    ~H"""
    <div :if={@modal?} phx-click-away="reset">
      <.live_component module={Modal} id="verification-modal">
        <.live_component
          module={@component}
          domain={@domain}
          id="verification-within-modal"
          modal?={@modal?}
          attempts={@attempts}
        />
      </.live_component>

      <PlausibleWeb.Components.Generic.button
        id="launch-verification-button"
        x-data
        x-on:click={Modal.JS.open("verification-modal")}
        phx-click="launch-verification"
        class="mt-6"
      >
        Verify your integration
      </PlausibleWeb.Components.Generic.button>
    </div>

    <.live_component
      :if={!@modal?}
      module={@component}
      domain={@domain}
      id="verification-standalone"
      attempts={@attempts}
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
      message: check.friendly_name()
    )

    {:noreply, socket}
  end

  def handle_info({:verification_end, %State{} = state}, socket) do
    rating = Checks.interpret_diagnostics(state)

    update_component(socket,
      finished?: true,
      success?: rating.ok?,
      rating: rating
    )

    {:noreply, assign(socket, checks_pid: nil)}
  end

  defp reset_component(socket) do
    update_component(socket,
      message: "We're visiting your site to ensure that everything is working correctly",
      finished?: false,
      success?: false,
      diagnostics: nil
    )

    socket
  end

  defp update_component(socket, updates) do
    send_update(
      @component,
      Keyword.merge(updates,
        id:
          if(socket.assigns.modal?,
            do: "verification-within-modal",
            else: "verification-standalone"
          )
      )
    )
  end

  defp launch_delayed(socket) do
    Process.send_after(self(), {:start, socket.assigns.report_to}, socket.assigns.delay)
  end
end
