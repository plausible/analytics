defmodule PlausibleWeb.Live.Dashboard.DetailsModal do
  @moduledoc """
  Live component for all brakdown details modals.
  """

  use PlausibleWeb, :live_component

  alias Plausible.Stats
  alias Plausible.Stats.Dashboard.Utils
  alias Plausible.Stats.ParsedQueryParams
  alias Plausible.Stats.QueryBuilder
  alias Plausible.Stats.QueryResult
  alias PlausibleWeb.Components.Dashboard.ReportList

  import PlausibleWeb.Components.Dashboard.Base

  @pagination %{limit: 50, offset: 0}

  def update(assigns, socket) do
    close_url = Utils.dashboard_route(assigns.site, assigns.params)

    socket =
      assign(socket,
        title: assigns.title,
        key: assigns.key,
        key_label: assigns.key_label,
        dimension: assigns.dimension,
        site: assigns.site,
        params: assigns.params,
        open?: assigns.open?,
        connected?: assigns.connected?,
        close_url: close_url
      )
      |> load_stats()

    {:ok, socket}
  end

  def render(assigns) do
    ~H"""
    <div>
      <.modal
        id={"#{@key}-breakdown-details-modal"}
        on_close={JS.patch(@close_url)}
        show={@open?}
        ready={@connected?}
      >
        <.modal_title>
          {@title}
        </.modal_title>

        <div class="group w-full h-full border-0 overflow-hidden">
          <ReportList.report
            site={@site}
            id={"#{@key}-detailed-list"}
            key_label={@key_label}
            dimension={@dimension}
            params={@params}
            query_result={@query_result}
            connected?={@connected?}
            external_link_fn={Utils.page_external_link_fn_for(@site)}
          />
        </div>
      </.modal>
    </div>
    """
  end

  defp load_stats(socket) do
    %{site: site, dimension: dimension, params: params} = socket.assigns

    metrics = choose_metrics(params)

    params =
      params
      |> ParsedQueryParams.set(
        metrics: metrics,
        dimensions: [dimension],
        pagination: @pagination
      )

    query = QueryBuilder.build!(site, params)

    %QueryResult{} = query_result = Stats.query(site, query)

    assign(socket, :query_result, query_result)
  end

  defp choose_metrics(%ParsedQueryParams{} = params) do
    if ParsedQueryParams.conversion_goal_filter?(params) do
      [:visitors, :group_conversion_rate]
    else
      [:visitors]
    end
  end
end
