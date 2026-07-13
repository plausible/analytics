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

    socket =
      socket
      |> assign(sort_by: sort_by, sort_direction: sort_direction)
      |> assign(TrialProspects.list(sort_by, sort_direction, parse_page(params["page"])))

    {:noreply, socket}
  end

  def render(assigns) do
    ~H"""
    <Layout.layout show_search={false} flash={@flash}>
      <div class="flex items-center justify-between">
        <h2 class="text-xl font-bold sm:text-2xl">🔥 Trial prospects</h2>
        <p class="text-sm text-gray-500 dark:text-gray-400">
          {@total_entries} active trials — ranked by estimated MRR potential
        </p>
      </div>

      <div class="mt-4">
        <.table rows={@prospects}>
          <:thead>
            <.th>Team</.th>
            <.sort_th
              label="MRR potential"
              by="mrr"
              sort_by={@sort_by}
              sort_direction={@sort_direction}
            />
            <.th>Feature tier</.th>
            <.th>Forced by</.th>
            <.th>Traffic estimate</.th>
            <.sort_th
              label="Trial start"
              by="trial_start"
              sort_by={@sort_by}
              sort_direction={@sort_direction}
            />
            <.th>Trial expiry</.th>
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

  defp sort_th(assigns) do
    active = assigns.sort_by == assigns.by
    assigns = assign(assigns, active: active, next_direction: next_direction(assigns, active))

    ~H"""
    <.th>
      <.link
        patch={
          Routes.customer_support_trial_prospects_path(PlausibleWeb.Endpoint, :index,
            sort_by: @by,
            sort_direction: @next_direction
          )
        }
        class="cursor-pointer select-none inline-flex items-center gap-1 hover:text-indigo-600 dark:hover:text-indigo-400"
      >
        {@label}
        <.sort_arrow active={@active} direction={@sort_direction} />
      </.link>
    </.th>
    """
  end

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
