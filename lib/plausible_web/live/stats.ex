defmodule PlausibleWeb.Live.Stats do
  @moduledoc false
  use PlausibleWeb, :live_view

  alias Plausible.Stats.{Filters, Query, QueryResult}
  alias Phoenix.LiveView.AsyncResult

  def mount(
        %{"domain" => domain},
        _session,
        socket
      ) do
    site =
      Plausible.Sites.get_for_user!(socket.assigns.current_user, domain,
        roles: [
          :owner,
          :admin,
          :editor,
          :super_admin,
          :viewer
        ]
      )

    {:ok,
     assign(socket,
       site: site,
       result: AsyncResult.loading()
     )}
  end

  def handle_info(_msg, socket) do
    {:noreply, socket}
  end

  def handle_params(params, _uri, socket) do
    site = socket.assigns.site
    {query, metric_names} = build_query(site, params)

    socket =
      socket
      |> assign(query: query, metric_names: metric_names)
      |> assign_async(:result, fn ->
        result = Plausible.Stats.query(site, query)
        {:ok, %{result: result}}
      end)

    {:noreply, socket}
  end

  def build_query(site, params) do
    {:ok, query} =
      Query.build(
        site,
        :internal,
        %{
          "site_id" => site.domain,
          "date_range" => params["date_range"],
          "filters" => dbg(url_filters_to_api_filters(JSON.decode!(params["filters"]))),
          # Placeholder metrics
          "metrics" => ["visitors"]
        },
        %{}
      )

    calculate_metrics(query, site)
  end

  def render(assigns) do
    ~H"""
    <div class="bg-white dark:bg-gray-825 flex flex-wrap overflow-hidden h-full">
      <.async_result :let={result} assign={@result}>
        <%= for {metric, value} <- zip_metrics(@query.metrics, result) do %>
          <.top_stat_metric name={Map.fetch!(@metric_names, metric)} value={value} metric={metric} />
        <% end %>
      </.async_result>
    </div>
    """
  end

  defp top_stat_metric(assigns) do
    # :TODO: Border classes depend on index, as in assets/js/dashboard/stats/graph/top-stats.js
    ~H"""
    <div class="relative px-4 md:px-6 w-1/2 my-4 lg:w-auto group select-none cursor-pointer border-r lg:border-r-0">
      <div class="text-xs font-bold tracking-wide text-gray-500 uppercase dark:text-gray-400 whitespace-nowrap flex w-content border-b group-hover:text-indigo-700 dark:group-hover:text-indigo-500 border-transparent">
        {@name}
      </div>
      <div class="my-1 space-y-2">
        <div>
          <span class="flex items-center justify-between whitespace-nowrap">
            <p class="font-bold text-xl dark:text-gray-100" id={@metric}>
              {format_metric(@metric, @value)}
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

  defp format_metric(metric, nil), do: "--"

  defp format_metric(metric, value) when metric in [:visitors, :visits, :pageviews] do
    PlausibleWeb.StatsView.large_number_format(value)
  end

  defp format_metric(metric, value) when metric in [:bounce_rate, :scroll_depth] do
    "#{value}%"
  end

  defp format_metric(:visit_duration, value) do
    hours = trunc(value / 60 / 60)
    minutes = rem(trunc(value / 60), 60)
    seconds = trunc(value - minutes * 60 - hours * 60 * 60)

    cond do
      hours > 0 -> "#{hours}h #{minutes}m #{seconds}s"
      minutes > 0 -> "#{minutes}m #{seconds}s"
      true -> "#{seconds}s"
    end
  end

  defp format_metric(metric, value) do
    value
  end

  defp zip_metrics(metrics, %QueryResult{results: [%{metrics: values}]}) do
    Enum.zip(metrics, values)
  end

  defp calculate_metrics(query, site) do
    goal_filter? = toplevel_goal_filter?(query)

    cond do
      # query.input_date_range == "30m" && goal_filter? ->
      #   goal_realtime_top_stats(site, query)

      # query.input_date_range == "30m" ->
      #   realtime_top_stats(site, query)

      # goal_filter? ->
      #   goal_top_stats(site, query)

      true ->
        other_top_stats(query, site)
    end
  end

  defp other_top_stats(query, site) do
    page_filter? =
      Filters.filtering_on_dimension?(query, "event:page", behavioral_filters: :ignore)

    metrics = [:visitors, :visits, :pageviews]

    metrics =
      cond do
        page_filter? && query.include_imported ->
          metrics ++ [:scroll_depth]

        page_filter? ->
          metrics ++ [:bounce_rate, :scroll_depth, :time_on_page]

        true ->
          metrics ++ [:views_per_visit, :bounce_rate, :visit_duration]
      end

    {
      Query.set(query, metrics: metrics),
      %{
        visitors: "Unique visitors",
        visits: "Total visits",
        pageviews: "Total pageviews",
        views_per_visit: "Views per visit",
        bounce_rate: "Bounce rate",
        visit_duration: "Visit duration",
        time_on_page: "Time on page",
        scroll_depth: "Scroll depth"
      }
    }
  end

  defp toplevel_goal_filter?(query) do
    Filters.filtering_on_dimension?(query, "event:goal",
      max_depth: 0,
      behavioral_filters: :ignore
    )
  end

  @visit_props Filters.visit_props()
  @event_props Filters.event_props()

  defp url_filters_to_api_filters(filters) do
    Filters.transform_filters(filters, fn
      [op, dim, clause] when dim in @visit_props -> [[op, "visit:" <> dim, clause]]
      [op, dim, clause] when dim in @event_props -> [[op, "event:" <> dim, clause]]
      _ -> nil
    end)
  end
end
