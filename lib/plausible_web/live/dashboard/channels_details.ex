defmodule PlausibleWeb.Live.Dashboard.ChannelsDetails do
  @moduledoc """
  Channels details modal breakdown component.
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
        id="channels-breakdown-details-modal"
        on_close={JS.patch(@close_url)}
        show={@open?}
        ready={@connected?}
      >
        <.modal_title>
          Channels
        </.modal_title>

        <div class="group w-full h-full border-0 overflow-hidden">
          <ReportList.report
            site={@site}
            data_test_id="channels-detailed-list"
            key_label="Channel"
            dimension="visit:channel"
            params={@params}
            query_result={@query_result}
            external_link_fn={Utils.page_external_link_fn_for(@site)}
          />
        </div>
      </.modal>
    </div>
    """
  end

  defp load_stats(socket) do
    %{site: site, params: params} = socket.assigns

    metrics = choose_metrics(params)

    params =
      params
      |> ParsedQueryParams.set(
        metrics: metrics,
        dimensions: ["visit:channel"],
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
