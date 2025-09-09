defmodule PlausibleWeb.Live.Stats do
  @moduledoc false
  use PlausibleWeb, :live_view

  alias Phoenix.LiveView.AsyncResult

  def mount(
        %{"domain" => domain},
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

    {:ok,
     assign(socket,
       site: site,
       status: AsyncResult.loading()
     )}
  end

  def handle_info(_msg, socket) do
    {:noreply, socket}
  end

  def render(assigns) do
    ~H"""
    <div class="container print:max-w-full">
      <div class="relative w-full mt-2 bg-white rounded shadow-xl dark:bg-gray-825">
        <div id="top-stats-container" class="flex flex-wrap " style="height: auto">
          <.top_stat_metric name="Unique visitors" value="552" metric="visitors" />
          <.top_stat_metric name="Total visits" value="552" metric="visits" />
          <.top_stat_metric name="Total pageviews" value="1.7k" metric="pageviews" />
          <.top_stat_metric name="Views per visit" value="3.14" metric="views_per_visit" />
          <.top_stat_metric name="Bounce rate" value="15%" metric="bounce_rate" />
          <.top_stat_metric name="Visit duration" value="6m 16s" metric="visit_duration" />
        </div>
      </div>
    </div>
    """
  end

  defp top_stat_metric(assigns) do
    ~H"""
    <div class="relative px-4 md:px-6 w-1/2 my-4 lg:w-auto group select-none cursor-pointer border-r lg:border-r-0">
      <div class="text-xs font-bold tracking-wide text-gray-500 uppercase dark:text-gray-400 whitespace-nowrap flex w-content border-b group-hover:text-indigo-700 dark:group-hover:text-indigo-500 border-transparent">
        {@name}
      </div>
      <div class="my-1 space-y-2">
        <div>
          <span class="flex items-center justify-between whitespace-nowrap">
            <p class="font-bold text-xl dark:text-gray-100" id={@metric}>
              {@value}
            </p>
            <.change_arrow />
          </span>
        </div>
      </div>
    </div>
    """
  end

  defp change_arrow(assigns) do
    ~H"""
    <span class="pl-2 text-xs dark:text-gray-100" data-testid="change-arrow">
      <svg
        xmlns="http://www.w3.org/2000/svg"
        viewBox="0 0 24 24"
        fill="currentColor"
        aria-hidden="true"
        data-slot="icon"
        class="text-red-400 inline-block h-3 w-3 stroke-[1px] stroke-current"
      >
        <path
          fill-rule="evenodd"
          d="M3.97 3.97a.75.75 0 0 1 1.06 0l13.72 13.72V8.25a.75.75 0 0 1 1.5 0V19.5a.75.75 0 0 1-.75.75H8.25a.75.75 0 0 1 0-1.5h9.44L3.97 5.03a.75.75 0 0 1 0-1.06Z"
          clip-rule="evenodd"
        />
      </svg>
      41%
    </span>
    """
  end
end
