defmodule Plausible.DataMigration.TeamsConsitencyCheck do
  @moduledoc """
  Verify consistency of teams.
  """

  import Ecto.Query

  alias Plausible.Teams

  @repo Plausible.DataMigration.PostgresRepo

  defmacrop is_distinct(f1, f2) do
    quote do
      fragment("? IS DISTINCT FROM ?", unquote(f1), unquote(f2))
    end
  end

  def run() do
    # Teams consistency check
    db_url =
      System.get_env(
        "TEAMS_MIGRATION_DB_URL",
        Application.get_env(:plausible, Plausible.Repo)[:url]
      )

    @repo.start(db_url, pool_size: 1)

    check()
  end

  defp check() do
    # Sites without teams

    sites_without_teams_count =
      from(
        s in Plausible.Site,
        where: is_nil(s.team_id)
      )
      |> @repo.aggregate(:count, timeout: :infinity)

    log("#{sites_without_teams_count} sites without teams")

    # Teams without owner

    owner_membership_query =
      from(
        tm in Teams.Membership,
        where: tm.team_id == parent_as(:team).id,
        where: tm.role == :owner,
        select: 1
      )

    teams_without_owner_count =
      from(
        t in Plausible.Teams.Team,
        as: :team,
        where: not exists(owner_membership_query)
      )
      |> @repo.aggregate(:count, timeout: :infinity)

    log("#{teams_without_owner_count} teams without owner")

    # Subscriptions without teams

    subscriptions_without_teams_count =
      from(
        s in Plausible.Billing.Subscription,
        where: is_nil(s.team_id)
      )
      |> @repo.aggregate(:count, timeout: :infinity)

    log("#{subscriptions_without_teams_count} subscriptions without teams")

    # Subscriptions out of sync

    subscriptions_out_of_sync_count =
      from(
        s in Plausible.Billing.Subscription,
        inner_join: u in assoc(s, :user),
        left_join: tm in assoc(u, :team_memberships),
        on: tm.role == :owner,
        where: s.team_id != tm.team_id
      )
      |> @repo.aggregate(:count, timeout: :infinity)

    log("#{subscriptions_out_of_sync_count} subscriptions out of sync")

    # Enterprise plans without teams

    enterprise_plans_without_teams_count =
      from(
        ep in Plausible.Billing.EnterprisePlan,
        where: is_nil(ep.team_id)
      )
      |> @repo.aggregate(:count, timeout: :infinity)

    log("#{enterprise_plans_without_teams_count} enterprise_plans without teams")

    # Enterprise plans out of sync

    enterprise_plans_out_of_sync_count =
      from(
        ep in Plausible.Billing.EnterprisePlan,
        inner_join: u in assoc(ep, :user),
        left_join: tm in assoc(u, :team_memberships),
        on: tm.role == :owner,
        where: ep.team_id != tm.team_id
      )
      |> @repo.aggregate(:count, timeout: :infinity)

    log("#{enterprise_plans_out_of_sync_count} enterprise_plans out of sync")

    # Teams out of sync

    teams_out_of_sync_count =
      from(
        t in Teams.Team,
        inner_join: tm in assoc(t, :team_memberships),
        inner_join: o in assoc(tm, :user),
        where: tm.role == :owner,
        where:
          is_distinct(o.trial_expiry_date, t.trial_expiry_date) or
            is_distinct(o.accept_traffic_until, t.accept_traffic_until) or
            is_distinct(o.allow_next_upgrade_override, t.allow_next_upgrade_override) or
            (is_distinct(o.grace_period, t.grace_period) and
               (is_distinct(o.grace_period["id"], t.grace_period["id"]) or
                  (is_nil(o.grace_period["is_over"]) and t.grace_period["is_over"] == true) or
                  (o.grace_period["is_over"] == true and t.grace_period["is_over"] == false) or
                  (o.grace_period["is_over"] == false and t.grace_period["is_over"] == true) or
                  is_distinct(o.grace_period["end_date"], t.grace_period["end_date"]) or
                  (is_nil(o.grace_period["manual_lock"]) and t.grace_period["manual_lock"] == true) or
                  (o.grace_period["manual_lock"] == true and
                     t.grace_period["manual_lock"] == false) or
                  (o.grace_period["manual_lock"] == false and
                     t.grace_period["manual_lock"] == true))),
        preload: [team_memberships: {tm, user: o}]
      )
      |> @repo.aggregate(:count, timeout: :infinity)

    log("#{teams_out_of_sync_count} teams out of sync")

    # Non-owner site memberships out of sync

    respective_guest_memberships_query =
      from(
        tm in Teams.Membership,
        inner_join: gm in assoc(tm, :guest_memberships),
        on:
          gm.site_id == parent_as(:site_membership).site_id and
            ((gm.role == :viewer and parent_as(:site_membership).role == :viewer) or
               (gm.role == :editor and parent_as(:site_membership).role == :admin)),
        where: tm.user_id == parent_as(:site_membership).user_id,
        select: 1
      )

    out_of_sync_nonowner_memberships_count =
      from(
        m in Plausible.Site.Membership,
        as: :site_membership,
        where: m.role != :owner,
        where: not exists(respective_guest_memberships_query)
      )
      |> @repo.aggregate(:count, timeout: :infinity)

    log("#{out_of_sync_nonowner_memberships_count} out of sync non-owner site memberships")

    # Owner site memberships out of sync

    respective_owner_memberships_query =
      from(
        tm in Teams.Membership,
        where: tm.team_id == parent_as(:site).team_id and tm.role == :owner,
        select: 1
      )

    out_of_sync_owner_memberships_count =
      from(
        m in Plausible.Site.Membership,
        as: :site_membership,
        inner_join: s in assoc(m, :site),
        as: :site,
        where: m.role == :owner,
        where: not exists(respective_owner_memberships_query)
      )
      |> @repo.aggregate(:count, timeout: :infinity)

    log("#{out_of_sync_owner_memberships_count} out of sync owner site memberships")

    # Site invitations out of sync

    respective_guest_invitations_query =
      from(
        gi in Teams.GuestInvitation,
        inner_join: ti in assoc(gi, :team_invitation),
        on: ti.email == parent_as(:site_invitation).email,
        where: gi.site_id == parent_as(:site_invitation).site_id,
        select: 1
      )

    out_of_sync_site_invitations_count =
      from(
        i in Plausible.Auth.Invitation,
        as: :site_invitation,
        where: i.role != :owner,
        where: not exists(respective_guest_invitations_query)
      )
      |> @repo.aggregate(:count, timeout: :infinity)

    log("#{out_of_sync_site_invitations_count} out of sync site invitations")

    # Site invitations out of sync

    respective_site_transfers_query =
      from(
        st in Teams.SiteTransfer,
        where: st.email == parent_as(:site_invitation).email,
        where: st.site_id == parent_as(:site_invitation).site_id,
        select: 1
      )

    out_of_sync_site_transfers_count =
      from(
        i in Plausible.Auth.Invitation,
        as: :site_invitation,
        where: i.role == :owner,
        where: not exists(respective_site_transfers_query)
      )
      |> @repo.aggregate(:count, timeout: :infinity)

    log("#{out_of_sync_site_transfers_count} out of sync site transfers")

    # Guest memberships out of sync

    respective_site_memberships_query =
      from(
        sm in Plausible.Site.Membership,
        where: sm.site_id == parent_as(:guest_membership).site_id,
        where: sm.user_id == parent_as(:team_membership).user_id,
        where:
          (sm.role == :viewer and parent_as(:guest_membership).role == :viewer) or
            (sm.role == :admin and parent_as(:guest_membership).role == :editor),
        select: 1
      )

    out_of_sync_guest_memberships_count =
      from(
        gm in Plausible.Teams.GuestMembership,
        as: :guest_membership,
        inner_join: tm in assoc(gm, :team_membership),
        as: :team_membership,
        where: tm.role != :owner,
        where: not exists(respective_site_memberships_query)
      )
      |> @repo.aggregate(:count, timeout: :infinity)

    log("#{out_of_sync_guest_memberships_count} out of sync guest memberships")

    # Owner memberships out of sync

    respective_site_memberships_query =
      from(
        sm in Plausible.Site.Membership,
        where: sm.site_id == parent_as(:site).id,
        where: sm.user_id == parent_as(:team_membership).user_id,
        where: sm.role == :owner,
        select: 1
      )

    out_of_sync_owner_memberships_count =
      from(
        tm in Plausible.Teams.Membership,
        as: :team_membership,
        inner_join: t in assoc(tm, :team),
        inner_join: s in assoc(t, :sites),
        as: :site,
        where: tm.role == :owner,
        where: not exists(respective_site_memberships_query)
      )
      |> @repo.aggregate(:count, timeout: :infinity)

    log("#{out_of_sync_owner_memberships_count} out of sync owner team memberships")

    # Guest invitations out of sync

    respective_site_invitations_query =
      from(
        i in Plausible.Auth.Invitation,
        where: i.site_id == parent_as(:guest_invitation).site_id,
        where: i.email == parent_as(:team_invitation).email,
        where:
          (i.role == :viewer and parent_as(:guest_invitation).role == :viewer) or
            (i.role == :admin and parent_as(:guest_invitation).role == :editor),
        where: i.invitation_id == parent_as(:guest_invitation).invitation_id,
        select: 1
      )

    out_of_sync_guest_invitations_count =
      from(
        gi in Plausible.Teams.GuestInvitation,
        as: :guest_invitation,
        inner_join: ti in assoc(gi, :team_invitation),
        as: :team_invitation,
        where: ti.role != :owner,
        where: not exists(respective_site_invitations_query)
      )
      |> @repo.aggregate(:count, timeout: :infinity)

    log("#{out_of_sync_guest_invitations_count} out of sync guest invitations")

    # Team site transfers out of sync

    respective_site_transfers_query =
      from(
        i in Plausible.Auth.Invitation,
        where: i.site_id == parent_as(:site_transfer).site_id,
        where: i.email == parent_as(:site_transfer).email,
        where: i.role == :owner,
        select: 1
      )

    out_of_sync_site_transfers_count =
      from(
        st in Plausible.Teams.SiteTransfer,
        as: :site_transfer,
        where: not exists(respective_site_transfers_query)
      )
      |> @repo.aggregate(:count, timeout: :infinity)

    log("#{out_of_sync_site_transfers_count} out of sync team site transfers")
  end

  defp log(msg) do
    IO.puts("[#{NaiveDateTime.utc_now(:second)}] #{msg}")
  end
end
