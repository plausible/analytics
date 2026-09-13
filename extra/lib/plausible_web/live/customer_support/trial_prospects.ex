defmodule PlausibleWeb.Live.CustomerSupport.TrialProspects do
  @moduledoc """
  Customer Support page listing active trials. Reads the
  cached `trial_prospects` table populated daily by
  `Plausible.Workers.ScoreTrialProspects`.
  """
  use PlausibleWeb.CustomerSupport.Live

  import PlausibleWeb.Live.Components.Pagination

  alias Plausible.CustomerSupport.TrialProspects
  alias PlausibleWeb.StatsView
  alias PlausibleWeb.TextHelpers

  def handle_params(params, _uri, socket) do
    sort_by =
      if params["sort_by"] in TrialProspects.sortable_columns(),
        do: params["sort_by"],
        else: "mrr"

    sort_direction =
      case params["sort_direction"] do
        "asc" -> :asc
        _ -> :desc
      end

    trial_status = if params["trial_status"] == "all", do: "all", else: "active"
    reviewed_status = if params["reviewed_status"] == "all", do: "all", else: "unreviewed"
    page = parse_page(params["page"])

    socket =
      socket
      |> assign(
        sort_by: sort_by,
        sort_direction: sort_direction,
        trial_status: trial_status,
        reviewed_status: reviewed_status,
        page_number: page
      )
      |> load_prospects()

    {:noreply, socket}
  end

  def handle_event("set-reviewed", %{"id" => id, "reviewed" => reviewed}, socket) do
    with {id, ""} <- Integer.parse(id) do
      TrialProspects.mark_reviewed(id, reviewed == "true")
    end

    {:noreply, load_prospects(socket)}
  end

  def render(assigns) do
    ~H"""
    <Layout.layout show_search={false} flash={@flash}>
      <div class="flex items-center justify-between">
        <h2 class="text-xl font-bold sm:text-2xl">🔥 Trial prospects</h2>
        <p class="text-sm text-gray-500 dark:text-gray-400">
          {@total_entries} prospects
        </p>
      </div>

      <div class="mt-4 flex flex-wrap gap-3">
        <div class="inline-flex rounded-md shadow-sm" role="group" aria-label="Trial status">
          <.filter_link
            active={@trial_status == "active"}
            patch={index_path(assigns, trial_status: "active", page: 1)}
          >
            Active trials
          </.filter_link>
          <.filter_link
            active={@trial_status == "all"}
            patch={index_path(assigns, trial_status: "all", page: 1)}
          >
            Include recently expired
          </.filter_link>
        </div>
        <div class="inline-flex rounded-md shadow-sm" role="group" aria-label="Review status">
          <.filter_link
            active={@reviewed_status == "unreviewed"}
            patch={index_path(assigns, reviewed_status: "unreviewed", page: 1)}
          >
            Unreviewed only
          </.filter_link>
          <.filter_link
            active={@reviewed_status == "all"}
            patch={index_path(assigns, reviewed_status: "all", page: 1)}
          >
            Include reviewed
          </.filter_link>
        </div>
      </div>

      <div class="mt-4">
        <.table rows={@prospects} row_attrs={&row_attrs/1}>
          <:thead>
            <.th>Team</.th>
            <.sort_th
              label="MRR potential"
              by="mrr"
              sort_by={@sort_by}
              sort_direction={@sort_direction}
              trial_status={@trial_status}
              reviewed_status={@reviewed_status}
            />
            <.th>Feature tier</.th>
            <.th>Forced by</.th>
            <.sort_th
              label="Traffic estimate"
              by="traffic"
              sort_by={@sort_by}
              sort_direction={@sort_direction}
              trial_status={@trial_status}
              reviewed_status={@reviewed_status}
            />
            <.sort_th
              label="Trial start"
              by="trial_start"
              sort_by={@sort_by}
              sort_direction={@sort_direction}
              trial_status={@trial_status}
              reviewed_status={@reviewed_status}
            />
            <.th>Trial expiry</.th>
            <.th>Review</.th>
          </:thead>
          <:tbody :let={p}>
            <.td>
              <.styled_link patch={
                Routes.customer_support_team_path(PlausibleWeb.Endpoint, :show, p.team.id)
              }>
                {p.team.name}
              </.styled_link>
              <div :if={owner_email(p.team)} class="text-xs text-gray-500 dark:text-gray-400">
                {owner_email(p.team)}
              </div>
            </.td>
            <.td>
              <span class="font-semibold">{mrr_label(p)}</span>
            </.td>
            <.td>
              <.pill color={kind_color(p.kind)} class="capitalize">{p.kind}</.pill>
            </.td>
            <.td>
              <div class="flex flex-wrap gap-1">
                <span :if={p.forced_by == []} class="text-gray-400 dark:text-gray-500">—</span>
                <.pill :for={gate <- p.forced_by} color={:gray}>{gate_label(gate)}</.pill>
              </div>
            </.td>
            <.td>{StatsView.large_number_format(p.estimated_monthly)}</.td>
            <.td>{format_date(trial_start(p.team))}</.td>
            <.td>{format_date(p.team.trial_expiry_date)}</.td>
            <.td>
              <button
                type="button"
                phx-click="set-reviewed"
                phx-value-id={p.id}
                phx-value-reviewed={if is_nil(p.reviewed_at), do: "true", else: "false"}
                class={[
                  "whitespace-nowrap rounded-md px-2 py-1 text-xs font-medium",
                  if(p.reviewed_at,
                    do:
                      "bg-gray-100 text-gray-600 hover:bg-gray-200 dark:bg-gray-700 dark:text-gray-300",
                    else:
                      "bg-indigo-50 text-indigo-700 hover:bg-indigo-100 dark:bg-indigo-900/50 dark:text-indigo-300"
                  )
                ]}
              >
                {if p.reviewed_at, do: "Reviewed", else: "Mark reviewed"}
              </button>
            </.td>
          </:tbody>
        </.table>

        <.pagination
          :if={@total_pages > 1}
          id="trial-prospects-pagination"
          uri={
            URI.new!(
              Routes.customer_support_trial_prospects_path(PlausibleWeb.Endpoint, :index,
                sort_by: @sort_by,
                sort_direction: @sort_direction,
                trial_status: @trial_status,
                reviewed_status: @reviewed_status,
                page: @page_number
              )
            )
          }
          page_number={@page_number}
          total_pages={@total_pages}
        >
          Total of <span class="font-medium">{@total_entries}</span>
          trials. Page {@page_number} of {@total_pages}
        </.pagination>

        <p :if={@prospects == []} class="text-sm text-gray-500 dark:text-gray-400">
          No trial prospects have been scored yet.
        </p>
      </div>
    </Layout.layout>
    """
  end

  attr :label, :string, required: true
  attr :by, :string, required: true
  attr :sort_by, :string, required: true
  attr :sort_direction, :atom, required: true
  attr :trial_status, :string, required: true
  attr :reviewed_status, :string, required: true

  defp sort_th(assigns) do
    active = assigns.sort_by == assigns.by
    assigns = assign(assigns, active: active, next_direction: next_direction(assigns, active))

    ~H"""
    <.th>
      <.link
        patch={index_path(assigns, sort_by: @by, sort_direction: @next_direction, page: 1)}
        class="cursor-pointer select-none inline-flex items-center gap-1 hover:text-indigo-600 dark:hover:text-indigo-400"
      >
        {@label}
        <.sort_arrow active={@active} direction={@sort_direction} />
      </.link>
    </.th>
    """
  end

  attr :active, :boolean, required: true
  attr :patch, :string, required: true
  slot :inner_block, required: true

  defp filter_link(assigns) do
    ~H"""
    <.link
      patch={@patch}
      class={[
        "border border-gray-200 px-3 py-2 text-sm first:rounded-l-md last:rounded-r-md dark:border-gray-700",
        if(@active,
          do: "bg-indigo-600 text-white dark:bg-indigo-500",
          else:
            "bg-white text-gray-700 hover:bg-gray-50 dark:bg-gray-800 dark:text-gray-300 dark:hover:bg-gray-750"
        )
      ]}
    >
      {render_slot(@inner_block)}
    </.link>
    """
  end

  defp load_prospects(socket) do
    assign(
      socket,
      TrialProspects.list(
        socket.assigns.sort_by,
        socket.assigns.sort_direction,
        socket.assigns.page_number,
        socket.assigns.trial_status,
        socket.assigns.reviewed_status
      )
    )
  end

  defp index_path(assigns, overrides) do
    params =
      [
        sort_by: assigns.sort_by,
        sort_direction: assigns.sort_direction,
        trial_status: assigns.trial_status,
        reviewed_status: assigns.reviewed_status,
        page: Map.get(assigns, :page_number, 1)
      ]
      |> Keyword.merge(overrides)

    Routes.customer_support_trial_prospects_path(PlausibleWeb.Endpoint, :index, params)
  end

  defp row_attrs(%{reviewed_at: nil}), do: %{}
  defp row_attrs(_reviewed), do: %{class: "opacity-60"}

  defp next_direction(%{sort_direction: :desc}, true), do: :asc
  defp next_direction(_assigns, _active), do: :desc

  defp parse_page(page) do
    case Integer.parse(page || "") do
      {n, _} when n > 0 -> n
      _ -> 1
    end
  end

  defp trial_start(team), do: NaiveDateTime.to_date(team.inserted_at)

  defp owner_email(team) do
    case team.owners do
      [owner | _] -> owner.email
      _ -> nil
    end
  end

  defp kind_color(:business), do: :indigo
  defp kind_color(:growth), do: :green
  defp kind_color(_), do: :gray

  defp gate_label("site_limit"), do: "Site limit"
  defp gate_label("team_member_limit"), do: "Team members"

  defp gate_label(feature) do
    case Plausible.Billing.Ecto.Feature.cast(feature) do
      {:ok, mod} -> mod.display_name()
      :error -> feature
    end
  end

  defp mrr_label(%{over_top_tier: true}), do: "Custom / Enterprise"
  defp mrr_label(%{estimated_mrr: nil}), do: "—"
  defp mrr_label(%{estimated_mrr: mrr}), do: "€#{TextHelpers.number_format(mrr)}/mo"

  defp format_date(nil), do: "—"
  defp format_date(date), do: TextHelpers.format_date(date)
end
