defmodule PlausibleWeb.Live.Verification do
  @moduledoc """
  LiveView coordinating the site verification process.
  Onboarding new sites, renders a standalone component.
  Embedded modal variant is available for general site settings.
  """
  use Plausible
  use PlausibleWeb, :live_view

  import PlausibleWeb.Components.Generic

  alias Plausible.InstallationSupport.{State, LegacyVerification, Verification}

  @component PlausibleWeb.Live.Components.Verification
  @slowdown_for_frequent_checking :timer.seconds(5)

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

    private = Map.get(socket.private.connect_info, :private, %{})

    super_admin? = Plausible.Auth.is_super_admin?(socket.assigns.current_user)
    has_pageviews? = has_pageviews?(site)
    custom_url_input? = params["custom_url"] == "true"

    socket =
      assign(socket,
        url_to_verify: nil,
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
        attempts: 0,
        polling_pageviews?: false,
        custom_url_input?: custom_url_input?
      )

    on_ee do
      if connected?(socket) and not custom_url_input? do
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

  def handle_event("verify-custom-url", %{"custom_url" => custom_url}, socket) do
    socket = launch_delayed(socket, custom_url)
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

      domain = socket.assigns.domain
      installation_type = socket.assigns.installation_type

      {:ok, pid} =
        if(
          FunWithFlags.enabled?(:scriptv2, for: socket.assigns.site) or
            FunWithFlags.enabled?(:scriptv2, for: socket.assigns.current_user),
          do:
            Verification.Checks.run(socket.assigns.url_to_verify, domain, installation_type,
              report_to: report_to,
              slowdown: socket.assigns.slowdown
            ),
          else:
            LegacyVerification.Checks.run(
              "https://#{socket.assigns.domain}",
              domain,
              report_to: report_to,
              slowdown: socket.assigns.slowdown
            )
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
    interpretation =
      if(FunWithFlags.enabled?(:scriptv2, for: socket.assigns.site),
        do: Verification.Checks.interpret_diagnostics(state),
        else: LegacyVerification.Checks.interpret_diagnostics(state)
      )

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
        socket
        |> assign(polling_pageviews?: false)
        |> schedule_pageviews_check()
      end

    {:noreply, socket}
  end

  defp schedule_pageviews_check(socket) do
    if socket.assigns.polling_pageviews? do
      socket
    else
      Process.send_after(self(), :check_pageviews, socket.assigns.delay * 2)
      assign(socket, polling_pageviews?: true)
    end
  end

  defp redirect_to_stats(socket) do
    stats_url = Routes.stats_path(PlausibleWeb.Endpoint, :stats, socket.assigns.domain, [])
    redirect(socket, to: stats_url)
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

  defp launch_delayed(socket, url_to_verify \\ nil) do
    socket =
      if is_binary(url_to_verify) do
        socket
        |> assign(url_to_verify: url_to_verify)
        |> assign(custom_url_input?: false)
      else
        socket
      end

    Process.send_after(self(), {:start, socket.assigns.report_to}, socket.assigns.delay)

    socket
  end

  defp has_pageviews?(site) do
    Plausible.Stats.Clickhouse.has_pageviews?(site)
  end

  on_ee do
    defp custom_url_form(assigns) do
      ~H"""
      <.focus_box>
        <div class="mx-auto flex h-12 w-12 items-center justify-center rounded-full bg-blue-100 dark:bg-blue-900">
          <Heroicons.globe_alt class="h-6 w-6 text-blue-600 dark:text-blue-200" />
        </div>
        <div class="mt-8">
          <h3 class="text-lg leading-6 font-medium text-gray-900 dark:text-white">
            Enter Your Custom URL
          </h3>
          <p class="text-sm mt-4 text-gray-600 dark:text-gray-400">
            Please enter the URL where your website with the Plausible script is located.
          </p>
          <form phx-submit="verify-custom-url" class="mt-6">
            <div class="mb-4">
              <label
                for="custom_url"
                class="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-2"
              >
                Website URL
              </label>
              <input
                type="url"
                name="custom_url"
                id="custom_url"
                required
                class="w-full px-3 py-2 border border-gray-300 dark:border-gray-600 rounded-md shadow-sm focus:outline-none focus:ring-indigo-500 focus:border-indigo-500 dark:bg-gray-800 dark:text-white"
                placeholder={"https://#{@domain}"}
                value={"https://#{@domain}"}
              />
            </div>
            <button
              type="submit"
              class="w-full flex justify-center py-2 px-4 border border-transparent rounded-md shadow-sm text-sm font-medium text-white bg-indigo-600 hover:bg-indigo-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500 dark:bg-indigo-500 dark:hover:bg-indigo-600"
            >
              Verify Installation
            </button>
          </form>
        </div>
      </.focus_box>
      """
    end
  end
end
