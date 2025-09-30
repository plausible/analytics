defmodule PlausibleWeb.Live.AwaitingPageviews do
  @moduledoc """
  A replacement for installation verification on Community Edition.
  """
  use PlausibleWeb, :live_view

  import PlausibleWeb.Components.Generic

  def mount(
        %{"domain" => domain} = params,
        _session,
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

    private = Map.get(socket.private.connect_info, :private, %{})

    has_pageviews? = has_pageviews?(site)

    socket =
      assign(socket,
        site: site,
        domain: domain,
        has_pageviews?: has_pageviews?,
        delay: private[:delay] || 500,
        flow: params["flow"] || "",
        polling_pageviews?: false
      )

    socket =
      if has_pageviews? do
        redirect_to_stats(socket)
      else
        schedule_pageviews_check(socket)
      end

    {:ok, socket}
  end

  def render(assigns) do
    ~H"""
    <PlausibleWeb.Components.FlowProgress.render flow={@flow} current_step="Verify installation" />
    <.awaiting_pageviews />
    """
  end

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

  defp has_pageviews?(site) do
    Plausible.Stats.Clickhouse.has_pageviews?(site)
  end
end
