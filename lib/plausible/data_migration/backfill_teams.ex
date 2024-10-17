defmodule Plausible.DataMigration.BackfillTeams do
  @moduledoc """
  Backfill and sync all teams related entities.
  """

  import Ecto.Query

  alias Plausible.Auth
  alias Plausible.Teams

  use Plausible.DataMigration, repo: Plausible.DataMigration.PostgresRepo, dir: false

  defmacrop is_distinct(f1, f2) do
    quote do
      fragment("? IS DISTINCT FROM ?", unquote(f1), unquote(f2))
    end
  end

  def run() do
    # Teams backfill
    db_url =
      System.get_env(
        "TEAMS_MIGRATION_DB_URL",
        Application.get_env(:plausible, Plausible.Repo)[:url]
      )

    @repo.start(db_url,
      pool_size: System.schedulers_online() * 2,
      ssl: true,
      ssl_opts: [verify: :verify_none]
    )

    backfill()
  end

  defp backfill() do
    sites_without_teams =
      from(
        s in Plausible.Site,
        inner_join: m in assoc(s, :memberships),
        inner_join: o in assoc(m, :user),
        where: m.role == :owner,
        where: is_nil(s.team_id),
        preload: [memberships: {m, user: o}]
      )
      |> @repo.all(timeout: :infinity)

    log("Found #{length(sites_without_teams)} sites without teams...")

    teams_count = backfill_teams(sites_without_teams)

    log("Backfilled #{teams_count} teams.")

    owner_site_memberships_query =
      from(
        tm in Plausible.Site.Membership,
        where: tm.user_id == parent_as(:user).id,
        where: tm.role == :owner,
        select: 1
      )

    users_with_subscriptions_without_sites =
      from(
        s in Plausible.Billing.Subscription,
        inner_join: u in assoc(s, :user),
        as: :user,
        where: not exists(owner_site_memberships_query),
        select: u,
        distinct: true
      )
      |> @repo.all(timeout: :infinity)

    log(
      "Found #{length(users_with_subscriptions_without_sites)} users with subscriptions without sites..."
    )

    teams_count = backfill_teams_for_users(users_with_subscriptions_without_sites)

    log("Backfilled #{teams_count} teams from users with subscriptions without sites.")

    # Stale teams sync

    stale_teams =
      from(
        t in Teams.Team,
        inner_join: tm in assoc(t, :team_memberships),
        inner_join: o in assoc(tm, :user),
        where: tm.role == :owner,
        where:
          is_distinct(o.trial_expiry_date, t.trial_expiry_date) or
            is_distinct(o.accept_traffic_until, t.accept_traffic_until) or
            is_distinct(o.allow_next_upgrade_override, t.allow_next_upgrade_override) or
            is_distinct(o.grace_period["id"], t.grace_period["id"]) or
            is_distinct(o.grace_period["is_over"], t.grace_period["is_over"]) or
            is_distinct(o.grace_period["end_date"], t.grace_period["end_date"]) or
            is_distinct(o.grace_period["manual_lock"], t.grace_period["manual_lock"]),
        preload: [team_memberships: {tm, user: o}]
      )
      |> @repo.all(timeout: :infinity)

    log("Found #{length(stale_teams)} teams which have fields out of sync...")

    sync_teams(stale_teams)

    # Subsciprtions backfill

    log("Brought out of sync teams up to date.")

    subscriptions_without_teams =
      from(
        s in Plausible.Billing.Subscription,
        inner_join: u in assoc(s, :user),
        inner_join: tm in assoc(u, :team_memberships),
        inner_join: t in assoc(tm, :team),
        where: tm.role == :owner,
        where: is_nil(s.team_id),
        preload: [user: {u, team_memberships: {tm, team: t}}]
      )
      |> @repo.all(timeout: :infinity)

    log("Found #{length(subscriptions_without_teams)} subscriptions without team...")

    backfill_subscriptions(subscriptions_without_teams)

    log("All subscriptions are linked to a team now.")

    # Enterprise plans backfill

    enterprise_plans_without_teams =
      from(
        ep in Plausible.Billing.EnterprisePlan,
        inner_join: u in assoc(ep, :user),
        inner_join: tm in assoc(u, :team_memberships),
        inner_join: t in assoc(tm, :team),
        where: tm.role == :owner,
        where: is_nil(ep.team_id),
        preload: [user: {u, team_memberships: {tm, team: t}}]
      )
      |> @repo.all(timeout: :infinity)

    log("Found #{length(enterprise_plans_without_teams)} enterprise plans without team...")

    backfill_enterprise_plans(enterprise_plans_without_teams)

    log("All enterprise plans are linked to a team now.")

    # Guest Memberships cleanup

    site_memberships_query =
      from(
        sm in Plausible.Site.Membership,
        where: sm.site_id == parent_as(:guest_membership).site_id,
        where: sm.user_id == parent_as(:team_membership).user_id,
        where: sm.role != :owner,
        select: 1
      )

    guest_memberships_to_remove =
      from(
        gm in Teams.GuestMembership,
        as: :guest_membership,
        inner_join: tm in assoc(gm, :team_membership),
        as: :team_membership,
        where: not exists(site_memberships_query)
      )
      |> @repo.all(timeout: :infinity)

    log("Found #{length(guest_memberships_to_remove)} guest memberships to remove...")

    team_ids_to_prune = remove_guest_memberships(guest_memberships_to_remove)

    log("Pruning guest team memberships for #{length(team_ids_to_prune)} teams...")

    from(t in Teams.Team, where: t.id in ^team_ids_to_prune)
    |> @repo.all(timeout: :infinity)
    |> Enum.each(fn team ->
      Plausible.Teams.Memberships.prune_guests(team)
    end)

    log("Guest memberships cleared.")

    # Guest Memberships backfill

    guest_memberships_query =
      from(
        gm in Teams.GuestMembership,
        inner_join: tm in assoc(gm, :team_membership),
        where: gm.site_id == parent_as(:site_membership).site_id,
        where: tm.user_id == parent_as(:site_membership).user_id,
        select: 1
      )

    site_memberships_to_backfill =
      from(
        sm in Plausible.Site.Membership,
        as: :site_membership,
        inner_join: s in assoc(sm, :site),
        inner_join: t in assoc(s, :team),
        inner_join: u in assoc(sm, :user),
        where: sm.role != :owner,
        where: not exists(guest_memberships_query),
        preload: [user: u, site: {s, team: t}]
      )
      |> @repo.all(timeout: :infinity)

    log(
      "Found #{length(site_memberships_to_backfill)} site memberships without guest membership..."
    )

    backfill_guest_memberships(site_memberships_to_backfill)

    log("Backfilled missing guest memberships.")

    # Stale guest memberships sync

    stale_guest_memberships =
      from(
        sm in Plausible.Site.Membership,
        inner_join: tm in Teams.Membership,
        on: tm.user_id == sm.user_id,
        inner_join: gm in assoc(tm, :guest_memberships),
        on: gm.site_id == sm.site_id,
        where: tm.role == :guest,
        where:
          (gm.role == :viewer and sm.role == :admin) or
            (gm.role == :editor and sm.role == :viewer),
        select: {gm, sm.role}
      )
      |> @repo.all(timeout: :infinity)

    log("Found #{length(stale_guest_memberships)} guest memberships with role out of sync...")

    sync_guest_memberships(stale_guest_memberships)

    log("All guest memberships are up to date now.")

    # Guest invitations cleanup

    site_invitations_query =
      from(
        i in Auth.Invitation,
        where: i.site_id == parent_as(:guest_invitation).site_id,
        where: i.email == parent_as(:team_invitation).email,
        where:
          (i.role == :viewer and parent_as(:guest_invitation).role == :viewer) or
            (i.role == :admin and parent_as(:guest_invitation).role == :editor)
      )

    guest_invitations_to_remove =
      from(
        gi in Teams.GuestInvitation,
        as: :guest_invitation,
        inner_join: ti in assoc(gi, :team_invitation),
        as: :team_invitation,
        where: not exists(site_invitations_query)
      )
      |> @repo.all(timeout: :infinity)

    log("Found #{length(guest_invitations_to_remove)} guest invitations to remove...")

    team_ids_to_prune = remove_guest_invitations(guest_invitations_to_remove)

    log("Pruning guest team invitations for #{length(team_ids_to_prune)} teams...")

    from(t in Teams.Team, where: t.id in ^team_ids_to_prune)
    |> @repo.all(timeout: :infinity)
    |> Enum.each(fn team ->
      Plausible.Teams.Invitations.prune_guest_invitations(team)
    end)

    log("Guest invitations cleared.")

    # Guest invitations backfill

    guest_invitations_query =
      from(
        gi in Teams.GuestInvitation,
        inner_join: ti in assoc(gi, :team_invitation),
        where: gi.site_id == parent_as(:site_invitation).site_id,
        where: ti.email == parent_as(:site_invitation).email,
        select: 1
      )

    site_invitations_to_backfill =
      from(
        si in Auth.Invitation,
        as: :site_invitation,
        inner_join: s in assoc(si, :site),
        inner_join: t in assoc(s, :team),
        inner_join: inv in assoc(si, :inviter),
        where: si.role != :owner,
        where: not exists(guest_invitations_query),
        preload: [site: {s, team: t}, inviter: inv]
      )
      |> @repo.all(timeout: :infinity)

    log(
      "Found #{length(site_invitations_to_backfill)} site invitations without guest invitation..."
    )

    backfill_guest_invitations(site_invitations_to_backfill)

    log("Backfilled missing guest invitations.")

    # Stale guest invitations sync

    stale_guest_invitations =
      from(
        si in Auth.Invitation,
        inner_join: ti in Teams.Invitation,
        on: ti.email == si.email,
        inner_join: gi in assoc(ti, :guest_invitations),
        on: gi.site_id == si.site_id,
        where: ti.role == :guest,
        where:
          (gi.role == :viewer and si.role == :admin) or
            (gi.role == :editor and si.role == :viewer),
        select: {gi, si.role}
      )
      |> @repo.all(timeout: :infinity)

    log("Found #{length(stale_guest_invitations)} guest invitations with role out of sync...")

    sync_guest_invitations(stale_guest_invitations)

    log("All guest invitations are up to date now.")

    # Site transfers cleanup

    site_invitations_query =
      from(
        i in Auth.Invitation,
        where: i.site_id == parent_as(:site_transfer).site_id,
        where: i.email == parent_as(:site_transfer).email,
        where: i.role == :owner
      )

    site_transfers_to_remove =
      from(
        st in Teams.SiteTransfer,
        as: :site_transfer,
        where: not exists(site_invitations_query)
      )
      |> @repo.all(timeout: :infinity)

    log("Found #{length(site_transfers_to_remove)} site transfers to remove...")

    remove_site_transfers(site_transfers_to_remove)

    log("Site transfers cleared.")

    # Site transfers backfill

    site_transfers_query =
      from(
        st in Teams.SiteTransfer,
        where: st.site_id == parent_as(:site_invitation).site_id,
        where: st.email == parent_as(:site_invitation).email,
        select: 1
      )

    site_invitations_to_backfill =
      from(
        si in Auth.Invitation,
        as: :site_invitation,
        inner_join: s in assoc(si, :site),
        inner_join: inv in assoc(si, :inviter),
        where: si.role == :owner,
        where: not exists(site_transfers_query),
        preload: [inviter: inv, site: s]
      )
      |> @repo.all(timeout: :infinity)

    log(
      "Found #{length(site_invitations_to_backfill)} ownership transfers without site transfer..."
    )

    backfill_site_transfers(site_invitations_to_backfill)

    log("Backfilled missing site transfers.")

    log("All data are up to date now!")
  end

  defp backfill_teams(sites) do
    sites
    |> Enum.map(fn %{id: site_id, memberships: [%{user: owner, role: :owner}]} ->
      {owner, site_id}
    end)
    |> Enum.group_by(&elem(&1, 0), &elem(&1, 1))
    |> tap(fn grouped ->
      if grouped != %{} do
        log("Teams about to be created: #{map_size(grouped)}")

        log(
          "Max sites: #{Enum.max_by(grouped, fn {_, sites} -> length(sites) end) |> elem(1) |> length()}"
        )
      end
    end)
    |> Enum.with_index()
    |> Task.async_stream(
      fn {{owner, site_ids}, idx} ->
        @repo.transaction(
          fn ->
            team =
              "My Team"
              |> Teams.Team.changeset()
              |> Ecto.Changeset.put_change(:trial_expiry_date, owner.trial_expiry_date)
              |> Ecto.Changeset.put_change(:accept_traffic_until, owner.accept_traffic_until)
              |> Ecto.Changeset.put_change(
                :allow_next_upgrade_override,
                owner.allow_next_upgrade_override
              )
              |> Ecto.Changeset.put_embed(:grace_period, owner.grace_period)
              |> @repo.insert!()

            team
            |> Teams.Membership.changeset(owner, :owner)
            |> @repo.insert!()

            @repo.update_all(from(s in Plausible.Site, where: s.id in ^site_ids),
              set: [team_id: team.id]
            )
          end,
          timeout: :infinity
        )

        if rem(idx, 10) == 0 do
          IO.write(".")
        end
      end,
      timeout: :infinity
    )
    |> Enum.to_list()
    |> length()
  end

  defp backfill_teams_for_users(users) do
    users
    |> Enum.with_index()
    |> Task.async_stream(
      fn {owner, idx} ->
        @repo.transaction(
          fn ->
            team =
              "My Team"
              |> Teams.Team.changeset()
              |> Ecto.Changeset.put_change(:trial_expiry_date, owner.trial_expiry_date)
              |> Ecto.Changeset.put_change(:accept_traffic_until, owner.accept_traffic_until)
              |> Ecto.Changeset.put_change(
                :allow_next_upgrade_override,
                owner.allow_next_upgrade_override
              )
              |> Ecto.Changeset.put_embed(:grace_period, owner.grace_period)
              |> @repo.insert!()

            team
            |> Teams.Membership.changeset(owner, :owner)
            |> @repo.insert!()
          end,
          timeout: :infinity
        )

        if rem(idx, 10) == 0 do
          IO.write(".")
        end
      end,
      timeout: :infinity
    )
    |> Enum.to_list()
    |> length()
  end

  defp sync_teams(stale_teams) do
    Enum.each(stale_teams, fn team ->
      [%{user: owner}] = team.team_memberships

      team
      |> Ecto.Changeset.change()
      |> Ecto.Changeset.put_change(:trial_expiry_date, owner.trial_expiry_date)
      |> Ecto.Changeset.put_change(:accept_traffic_until, owner.accept_traffic_until)
      |> Ecto.Changeset.put_change(
        :allow_next_upgrade_override,
        owner.allow_next_upgrade_override
      )
      |> Ecto.Changeset.put_embed(:grace_period, owner.grace_period)
      |> @repo.update!()
    end)
  end

  defp backfill_subscriptions(subscriptions) do
    subscriptions
    |> Enum.with_index()
    |> Task.async_stream(
      fn {subscription, idx} ->
        [%{team: team, role: :owner}] = subscription.user.team_memberships

        subscription
        |> Ecto.Changeset.change(team_id: team.id)
        |> @repo.update!()

        if rem(idx, 1000) == 0 do
          IO.write(".")
        end
      end,
      timeout: :infinity
    )
    |> Stream.run()
  end

  defp backfill_enterprise_plans(enterprise_plans) do
    enterprise_plans
    |> Enum.with_index()
    |> Task.async_stream(
      fn {enterprise_plan, idx} ->
        [%{team: team, role: :owner}] = enterprise_plan.user.team_memberships

        enterprise_plan
        |> Ecto.Changeset.change(team_id: team.id)
        |> @repo.update!()

        if rem(idx, 1000) == 0 do
          IO.write(".")
        end
      end,
      timeout: :infinity
    )
    |> Stream.run()
  end

  defp remove_guest_memberships(guest_memberships) do
    ids = Enum.map(guest_memberships, & &1.id)

    {_, team_ids} =
      @repo.delete_all(
        from(
          gm in Teams.GuestMembership,
          inner_join: tm in assoc(gm, :team_membership),
          where: gm.id in ^ids,
          select: tm.team_id
        )
      )

    Enum.uniq(team_ids)
  end

  defp backfill_guest_memberships(site_memberships) do
    now = NaiveDateTime.utc_now(:second)

    site_memberships
    |> Enum.group_by(&{&1.site.team, &1.user}, &{&1.site, &1.role})
    |> tap(fn grouped ->
      if grouped != %{} do
        log("Team memberships to be created: #{map_size(grouped)}")

        log(
          "Max guest memberships: #{Enum.max_by(grouped, fn {_, gms} -> length(gms) end) |> elem(1) |> length()}"
        )
      end
    end)
    |> Enum.with_index()
    |> Task.async_stream(
      fn {{{team, user}, sites_and_roles}, idx} ->
        team_membership =
          team
          |> Teams.Membership.changeset(user, :guest)
          |> @repo.insert!(
            on_conflict: [set: [updated_at: now]],
            conflict_target: [:team_id, :user_id]
          )

        Enum.each(sites_and_roles, fn {site, role} ->
          team_membership
          |> Teams.GuestMembership.changeset(site, translate_role(role))
          |> @repo.insert!()
        end)

        if rem(idx, 1000) == 0 do
          IO.write(".")
        end
      end,
      timeout: :infinity
    )
    |> Stream.run()
  end

  defp sync_guest_memberships(guest_memberships_and_roles) do
    guest_memberships_and_roles
    |> Enum.with_index()
    |> Enum.each(fn {{guest_membership, role}, idx} ->
      guest_membership
      |> Ecto.Changeset.change(role: translate_role(role))
      |> @repo.update!()

      if rem(idx, 1000) == 0 do
        IO.write(".")
      end
    end)
  end

  defp remove_guest_invitations(guest_invitations) do
    ids = Enum.map(guest_invitations, & &1.id)

    {_, team_ids} =
      @repo.delete_all(
        from(
          gi in Teams.GuestInvitation,
          inner_join: ti in assoc(gi, :team_invitation),
          where: gi.id in ^ids,
          select: ti.team_id
        )
      )

    Enum.uniq(team_ids)
  end

  defp backfill_guest_invitations(site_invitations) do
    site_invitations
    |> Enum.group_by(&{&1.site.team, &1.email}, &{&1.site, &1.role, &1.inviter, &1.invitation_id})
    |> Enum.with_index()
    |> Enum.each(fn {{{team, email}, sites_and_roles}, idx} ->
      now = NaiveDateTime.utc_now(:second)

      {_, _, inviter, invitation_id} = List.first(sites_and_roles)

      team_invitation =
        team
        # NOTE: we put first inviter and invitation ID matching team/email combination
        |> Teams.Invitation.changeset(email: email, role: :guest, inviter: inviter)
        |> Ecto.Changeset.put_change(:invitation_id, invitation_id)
        |> @repo.insert!(
          on_conflict: [set: [updated_at: now]],
          conflict_target: [:team_id, :email]
        )

      Enum.each(sites_and_roles, fn {site, role, _} ->
        team_invitation
        |> Teams.GuestInvitation.changeset(site, translate_role(role))
        |> @repo.insert!()
      end)

      if rem(idx, 1000) == 0 do
        IO.write(".")
      end
    end)
  end

  defp sync_guest_invitations(guest_invitations_and_roles) do
    guest_invitations_and_roles
    |> Enum.with_index()
    |> Enum.each(fn {{guest_invitation, role}, idx} ->
      guest_invitation
      |> Ecto.Changeset.change(role: translate_role(role))
      |> @repo.update!()

      if rem(idx, 1000) == 0 do
        IO.write(".")
      end
    end)
  end

  defp remove_site_transfers(site_transfers) do
    ids = Enum.map(site_transfers, & &1.id)

    @repo.delete_all(from(st in Teams.SiteTransfer, where: st.id in ^ids))
  end

  defp backfill_site_transfers(site_invitations) do
    site_invitations
    |> Enum.with_index()
    |> Enum.each(fn {site_invitation, idx} ->
      site_invitation.site
      |> Teams.SiteTransfer.changeset(
        initiator: site_invitation.inviter,
        email: site_invitation.email
      )
      |> Ecto.Changeset.put_change(:transfer_id, site_invitation.invitation_id)
      |> @repo.insert!()

      if rem(idx, 1000) == 0 do
        IO.write(".")
      end
    end)
  end

  defp translate_role(:admin), do: :editor
  defp translate_role(:viewer), do: :viewer

  defp log(msg) do
    IO.puts("[#{NaiveDateTime.utc_now(:second)}] #{msg}")
  end
end
