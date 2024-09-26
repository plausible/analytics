defmodule Plausible.Teams.Billing do
  @moduledoc false

  import Ecto.Query

  alias Plausible.Billing.Plans
  alias Plausible.Repo
  alias Plausible.Teams

  @team_member_limit_for_trials 3

  def team_member_limit(team) do
    team = Teams.with_subscription(team)

    case Plans.get_subscription_plan(team.subscription) do
      %{team_member_limit: limit} -> limit
      :free_10k -> :unlimited
      nil -> @team_member_limit_for_trials
    end
  end

  def team_member_usage(team, opts) do
    exclude_emails = Keyword.get(opts, :exclude_emails, [])

    site_ids =
      case Keyword.get(opts, :pending_ownership_site_ids) do
        [_ | _] = pending_ids -> pending_ids
        _ -> []
      end

    team
    |> query_team_member_emails(site_ids, exclude_emails)
    |> Repo.aggregate(:count)
  end

  defp query_team_member_emails(team, site_ids, exclude_emails) do
    pending_memberships_q =
      from tm in Teams.Membership,
        inner_join: u in assoc(tm, :user),
        inner_join: gm in assoc(tm, :guest_memberships),
        where: gm.site_id in ^site_ids and tm.role != :owner,
        where: u.email not in ^exclude_emails,
        select: %{email: u.email}

    pending_invitations_q =
      from ti in Teams.Invitation,
        inner_join: gi in assoc(ti, :guest_invitations),
        where: gi.site_id in ^site_ids and ti.role != :owner,
        where: ti.email not in ^exclude_emails,
        select: %{email: ti.email}

    team_memberships_q =
      from tm in Teams.Membership,
        inner_join: u in assoc(tm, :user),
        where: tm.team_id == ^team.id and tm.role != :owner,
        where: u.email not in ^exclude_emails,
        select: %{email: u.email}

    team_invitations_q =
      from ti in Teams.Invitation,
        where: ti.team_id == ^team.id and ti.role != :owner,
        where: ti.email not in ^exclude_emails,
        select: %{email: ti.email}

    pending_memberships_q
    |> union(^pending_invitations_q)
    |> union(^team_memberships_q)
    |> union(^team_invitations_q)
  end
end
