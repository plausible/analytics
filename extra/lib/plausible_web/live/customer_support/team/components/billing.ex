defmodule PlausibleWeb.CustomerSupport.Team.Components.Billing do
  @moduledoc """
  Team billing component - handles subscription and custom plans
  """
  use PlausibleWeb, :live_component
  import PlausibleWeb.CustomerSupport.Live

  alias Plausible.Billing.EnterprisePlan
  alias Plausible.Billing.Plans
  alias Plausible.Teams
  import Ecto.Query, only: [from: 2]
  import PlausibleWeb.Components.Generic

  require Plausible.Billing.Subscription.Status

  def update(%{team: team}, socket) do
    usage = Teams.Billing.quota_usage(team, with_features: true)

    limits = %{
      monthly_pageviews: Teams.Billing.monthly_pageview_limit(team),
      sites: Teams.Billing.site_limit(team),
      team_members: Teams.Billing.team_member_limit(team)
    }

    plans = get_plans(team.id)
    plan = Plans.get_subscription_plan(team.subscription)

    attrs = get_plan_attrs(plan)
    plan_form = to_form(EnterprisePlan.changeset(%EnterprisePlan{}, attrs))

    {:ok,
     assign(socket,
       team: team,
       usage: usage,
       limits: limits,
       plan: plan,
       plans: plans,
       plan_form: plan_form,
       show_plan_form?: false,
       editing_plan: nil,
       cost_estimate: 0
     )}
  end

  def render(assigns) do
    ~H"""
    <div>
      <script type="text/javascript">
        const featureChangeCallback = function(e) {
          const value = e.target.value
          const checked = e.target.checked
          const form = e.target.closest('form')

          if (value === 'sites_api' && checked) {
            form.querySelector('input[value=stats_api]').checked = true
          } else if (value === 'stats_api' && !checked) {
            form.querySelector('input[value=sites_api]').checked = false
          }
        }
      </script>
      <div class="mt-4 mb-4 text-gray-900 dark:text-gray-400">
        <h1 class="text-xs font-semibold">Usage</h1>
        <.table rows={monthly_pageviews_usage(@usage.monthly_pageviews, @limits.monthly_pageviews)}>
          <:thead>
            <.th invisible>Cycle</.th>
            <.th invisible>Dates</.th>
            <.th>Total</.th>
            <.th>Limit</.th>
          </:thead>
          <:tbody :let={{cycle, date, total, limit}}>
            <.td>{cycle}</.td>
            <.td>{date}</.td>
            <.td>
              <span class={if total > limit, do: "text-red-600"}>{number_format(total)}</span>
            </.td>
            <.td>{number_format(limit)}</.td>
          </:tbody>
        </.table>

        <p :if={@usage.features != []} class="mt-6 mb-4">
          <h1 class="text-xs font-semibold">Features Used</h1>
          <span class="text-sm">
            {@usage.features |> Enum.map(& &1.display_name()) |> Enum.join(", ")}
          </span>
        </p>

        <h1 :if={!@show_plan_form? and @plans != []} class="mt-8 text-xs font-semibold">
          Custom Plans
        </h1>
        <.table :if={!@show_plan_form?} rows={@plans}>
          <:thead>
            <.th invisible>Interval</.th>
            <.th>Paddle Plan ID</.th>
            <.th>Limits</.th>
            <.th>Features</.th>
            <.th invisible>Actions</.th>
          </:thead>
          <:tbody :let={plan}>
            <.td class="align-top">
              {plan.billing_interval}
            </.td>
            <.td class="align-top">
              {plan.paddle_plan_id}

              <span
                :if={(@team.subscription && @team.subscription.paddle_plan_id) == plan.paddle_plan_id}
                class="inline-flex items-center px-2 py-0.5 rounded text-xs font-xs bg-red-100 text-red-800"
              >
                CURRENT
              </span>
            </.td>
            <.td max_width="max-w-40">
              <.table rows={[
                {"Pageviews", number_format(plan.monthly_pageview_limit)},
                {"Sites", number_format(plan.site_limit)},
                {"Members", number_format(plan.team_member_limit)},
                {"API Requests", number_format(plan.hourly_api_request_limit)}
              ]}>
                <:tbody :let={{label, value}}>
                  <.td>{label}</.td>
                  <.td>{value}</.td>
                </:tbody>
              </.table>
            </.td>
            <.td class="align-top">
              <span :for={feat <- plan.features}>{feat.display_name()}<br /></span>
            </.td>
            <.td class="align-top">
              <.edit_button phx-click="edit-plan" phx-value-id={plan.id} phx-target={@myself} />
            </.td>
          </:tbody>
        </.table>

        <.form
          :let={f}
          :if={@show_plan_form?}
          for={@plan_form}
          id="save-plan"
          phx-submit={if @editing_plan, do: "update-plan", else: "save-plan"}
          phx-target={@myself}
          phx-change="estimate-cost"
        >
          <.input field={f[:paddle_plan_id]} label="Paddle Plan ID" autocomplete="off" />
          <.input
            type="select"
            options={["monthly", "yearly"]}
            field={f[:billing_interval]}
            label="Billing Interval"
            autocomplete="off"
          />

          <div class="flex items-center gap-x-4">
            <.input
              field={f[:monthly_pageview_limit]}
              label="Monthly Pageview Limit"
              autocomplete="off"
              width="w-[500]"
            />
            <.preview for={f[:monthly_pageview_limit]} />
          </div>

          <div class="flex items-center gap-x-4">
            <.input width="w-[500]" field={f[:site_limit]} label="Site Limit" autocomplete="off" />
            <.preview for={f[:site_limit]} />
          </div>

          <div class="flex items-center gap-x-4">
            <.input
              field={f[:team_member_limit]}
              label="Team Member Limit"
              autocomplete="off"
              width="w-[500]"
            />
            <.preview for={f[:team_member_limit]} />
          </div>

          <div class="flex items-center gap-x-4">
            <.input
              field={f[:hourly_api_request_limit]}
              label="Hourly API Request Limit"
              autocomplete="off"
              width="w-[500]"
            />
            <.preview for={f[:hourly_api_request_limit]} />
          </div>

          <.input
            :for={
              mod <-
                Plausible.Billing.Feature.list()
                |> Enum.sort_by(fn item -> if item.name() == :stats_api, do: 0, else: 1 end)
            }
            :if={not mod.free?()}
            x-on:change="featureChangeCallback(event)"
            type="checkbox"
            value={mod in (f.source.changes[:features] || f.source.data.features || [])}
            name={"#{f.name}[features[]][#{mod.name()}]"}
            label={mod.display_name()}
          />

          <div class="mt-8 flex align-center gap-x-4">
            <.input_with_clipboard
              id="cost-estimate"
              name="cost-estimate"
              label={"#{(f[:billing_interval].value || "monthly")} cost estimate"}
              value={@cost_estimate}
            />

            <.button theme="bright" phx-click="hide-plan-form" phx-target={@myself}>
              Cancel
            </.button>

            <.button type="submit">
              {if @editing_plan, do: "Update Plan", else: "Save Custom Plan"}
            </.button>
          </div>
        </.form>

        <.button
          :if={!@show_plan_form?}
          id="new-custom-plan"
          phx-click="show-plan-form"
          phx-target={@myself}
        >
          New Custom Plan
        </.button>
      </div>
    </div>
    """
  end

  # Event handlers
  def handle_event("show-plan-form", _, socket) do
    {:noreply, assign(socket, show_plan_form?: true, editing_plan: nil)}
  end

  def handle_event("edit-plan", %{"id" => plan_id}, socket) do
    {plan_id, _} = Integer.parse(plan_id)
    plan = Enum.find(socket.assigns.plans, &(&1.id == plan_id))

    if plan do
      plan_form = to_form(EnterprisePlan.changeset(plan, %{}))
      {:noreply, assign(socket, show_plan_form?: true, editing_plan: plan, plan_form: plan_form)}
    else
      {:noreply, socket}
    end
  end

  def handle_event("hide-plan-form", _, socket) do
    {:noreply, assign(socket, show_plan_form?: false, editing_plan: nil)}
  end

  def handle_event("estimate-cost", %{"enterprise_plan" => params}, socket) do
    params = update_features_to_list(params)

    form = to_form(EnterprisePlan.changeset(%EnterprisePlan{}, params))
    params = sanitize_params(params)

    cost_estimate =
      Plausible.CustomerSupport.EnterprisePlan.estimate(
        params["billing_interval"],
        get_int_param(params, "monthly_pageview_limit"),
        get_int_param(params, "site_limit"),
        get_int_param(params, "team_member_limit"),
        get_int_param(params, "hourly_api_request_limit"),
        params["features"]
      )

    {:noreply, assign(socket, cost_estimate: cost_estimate, plan_form: form)}
  end

  def handle_event("save-plan", %{"enterprise_plan" => params}, socket) do
    params = params |> update_features_to_list() |> sanitize_params()
    changeset = EnterprisePlan.changeset(%EnterprisePlan{team_id: socket.assigns.team.id}, params)

    case Plausible.Repo.insert(changeset) do
      {:ok, _plan} ->
        success("Plan saved")
        plans = get_plans(socket.assigns.team.id)

        {:noreply,
         assign(socket,
           plans: plans,
           plan_form: to_form(changeset),
           show_plan_form?: false,
           editing_plan: nil
         )}

      {:error, changeset} ->
        failure("Error saving plan: #{inspect(changeset.errors)}")
        {:noreply, assign(socket, plan_form: to_form(changeset))}
    end
  end

  def handle_event("update-plan", %{"enterprise_plan" => params}, socket) do
    params = params |> update_features_to_list() |> sanitize_params()
    changeset = EnterprisePlan.changeset(socket.assigns.editing_plan, params)

    case Plausible.Repo.update(changeset) do
      {:ok, _plan} ->
        success("Plan updated")
        plans = get_plans(socket.assigns.team.id)

        {:noreply,
         assign(socket,
           plans: plans,
           plan_form: to_form(changeset),
           show_plan_form?: false,
           editing_plan: nil
         )}

      {:error, changeset} ->
        failure("Error updating plan: #{inspect(changeset.errors)}")
        {:noreply, assign(socket, plan_form: to_form(changeset))}
    end
  end

  # Helper functions
  defp get_plan_attrs(plan) when is_map(plan) do
    Map.take(plan, [
      :billing_interval,
      :monthly_pageview_limit,
      :site_limit,
      :team_member_limit,
      :hourly_api_request_limit,
      :features
    ])
    |> Map.update(:features, [], fn features ->
      Enum.map(features, &to_string(&1.name()))
    end)
  end

  defp get_plan_attrs(_) do
    %{
      monthly_pageview_limit: 10_000,
      hourly_api_request_limit: 600,
      site_limit: 10,
      team_member_limit: 10,
      features: Plausible.Billing.Feature.list() -- [Plausible.Billing.Feature.SSO]
    }
  end

  defp monthly_pageviews_usage(usage, limit) do
    usage
    |> Enum.sort_by(fn {_cycle, usage} -> usage.date_range.first end, :desc)
    |> Enum.map(fn {cycle, usage} ->
      {cycle, PlausibleWeb.TextHelpers.format_date_range(usage.date_range), usage.total, limit}
    end)
  end

  defp get_plans(team_id) do
    Plausible.Repo.all(
      from ep in EnterprisePlan,
        where: ep.team_id == ^team_id,
        order_by: [desc: :id]
    )
  end

  defp number_format(unlimited) when unlimited in [-1, "unlimited", :unlimited] do
    "unlimited"
  end

  defp number_format(number) when is_integer(number) do
    Cldr.Number.to_string!(number)
  end

  defp number_format(other), do: other

  defp sanitize_params(params) do
    params
    |> Enum.map(&clear_param/1)
    |> Enum.reject(&(&1 == ""))
    |> Map.new()
  end

  defp clear_param({key, value}) when is_binary(value) do
    {key, String.trim(value)}
  end

  defp clear_param(other) do
    other
  end

  defp get_int_param(params, key) do
    param = Map.get(params, key)
    param = if param in ["", nil], do: "0", else: param

    case Integer.parse(param) do
      {integer, ""} -> integer
      _ -> 0
    end
  end

  defp update_features_to_list(params) do
    features =
      params["features[]"]
      |> Enum.reject(fn {_key, value} -> value == "false" or value == "" end)
      |> Enum.map(fn {key, _value} -> key end)

    Map.put(params, "features", features)
  end

  defp preview_number(n) do
    case Integer.parse("#{n}") do
      {n, ""} ->
        number_format(n) <> " (#{PlausibleWeb.StatsView.large_number_format(n)})"

      _ ->
        "0"
    end
  end

  attr :for, :any, required: true

  defp preview(assigns) do
    ~H"""
    <.input
      name={"#{@for.name}-preview"}
      label="Preview"
      autocomplete="off"
      width="w-[500]"
      readonly
      value={preview_number(@for.value)}
      class="bg-transparent border-0 p-0 m-0 text-sm w-full"
    />
    """
  end
end
