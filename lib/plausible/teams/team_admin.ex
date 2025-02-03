defmodule Plausible.Teams.TeamAdmin do
  @moduledoc """
  Kaffy CRM definition for Team.
  """

  use Plausible
  use Plausible.Repo

  alias Plausible.Teams
  alias Plausible.Billing.Subscription

  require Plausible.Billing.Subscription.Status

  def custom_index_query(_conn, _schema, query) do
    from(t in query,
      as: :team,
      left_lateral_join: s in subquery(Teams.last_subscription_join_query()),
      on: true,
      preload: [:owners, team_memberships: :user, subscription: s]
    )
  end

  def index(_) do
    [
      name: %{value: &team_name/1},
      inserted_at: %{name: "Created at", value: &format_date(&1.inserted_at)},
      other_members: %{value: &get_other_members/1},
      trial_expiry_date: %{name: "Trial expiry", value: &format_date(&1.trial_expiry_date)},
      subscription_plan: %{value: &subscription_plan/1},
      subscription_status: %{value: &subscription_status/1},
      grace_period: %{value: &grace_period_status/1},
      accept_traffic_until: %{
        name: "Accept traffic until",
        value: &format_date(&1.accept_traffic_until)
      }
    ]
  end

  defp team_name(team) do
    "#{team.name} (#{team.owners |> Enum.map(& &1.email) |> Enum.join(", ")})"
  end

  defp grace_period_status(team) do
    grace_period = team.grace_period

    case grace_period do
      nil ->
        "--"

      %{manual_lock: true, is_over: true} ->
        "Manually locked"

      %{manual_lock: true, is_over: false} ->
        "Waiting for manual lock"

      %{is_over: true} ->
        "ended"

      %{end_date: %Date{} = end_date} ->
        days_left = Date.diff(end_date, Date.utc_today())
        "#{days_left} days left"
    end
  end

  defp subscription_plan(team) do
    subscription = team.subscription

    if Subscription.Status.active?(subscription) && subscription.paddle_subscription_id do
      quota = PlausibleWeb.AuthView.subscription_quota(subscription)
      interval = PlausibleWeb.AuthView.subscription_interval(subscription)

      {:safe, ~s(<a href="#{manage_url(subscription)}">#{quota} \(#{interval}\)</a>)}
    else
      "--"
    end
  end

  defp subscription_status(team) do
    cond do
      team && team.subscription ->
        status_str =
          PlausibleWeb.SettingsView.present_subscription_status(team.subscription.status)

        if team.subscription.paddle_subscription_id do
          {:safe, ~s(<a href="#{manage_url(team.subscription)}">#{status_str}</a>)}
        else
          status_str
        end

      Plausible.Teams.on_trial?(team) ->
        "On trial"

      true ->
        "Trial expired"
    end
  end

  defp manage_url(%{paddle_subscription_id: paddle_id} = _subscription) do
    Plausible.Billing.PaddleApi.vendors_domain() <>
      "/subscriptions/customers/manage/" <> paddle_id
  end

  defp get_other_members(team) do
    team.team_memberships
    |> Enum.reject(&(&1.role == :owner))
    |> Enum.map(fn tm -> tm.user.email <> "(#{tm.role})" end)
    |> Enum.join(", ")
  end

  defp format_date(nil), do: "--"

  defp format_date(date) do
    Calendar.strftime(date, "%b %-d, %Y")
  end
end
