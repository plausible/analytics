defmodule Plausible.DataMigration.BackfillTeams do
  @moduledoc """
  Backfill and sync all teams related entities.
  """

  import Ecto.Query

  alias Plausible.{Repo, Teams}

  defmacrop is_distinct(f1, f2) do
    quote do
      fragment("? IS DISTINCT FROM ?", unquote(f1), unquote(f2))
    end
  end

  def run(opts \\ []) do
    Application.ensure_all_started(:cloak)
    Application.ensure_all_started(:cloak_ecto)
    Plausible.Auth.TOTP.Vault.start_link(key: totp_vault_key())
  rescue
    _ ->
      :ok

      dry_run? = Keyword.get(opts, :dry_run?, true)
      Repo.transaction(fn -> backfill(dry_run?) end, timeout: :infinity)
  end

  defp backfill(dry_run?) do
    # Orphaned teams

    orphaned_teams =
      from(
        t in Plausible.Teams.Team,
        left_join: tm in assoc(t, :team_memberships),
        where: is_nil(tm.id),
        left_join: s in assoc(t, :sites),
        where: is_nil(s.id)
      )
      |> Repo.all(timeout: :infinity)

    log("Found #{length(orphaned_teams)} orphaned teams...")

    if not dry_run? do
      delete_orphaned_teams(orphaned_teams)

      log("Deleted orphaned teams")
    end

    # Sites without teams

    sites_without_teams =
      from(
        s in Plausible.Site,
        inner_join: m in "site_memberships",
        on: m.site_id == s.id,
        inner_join: o in Plausible.Auth.User,
        on: o.id == m.user_id,
        where: m.role == "owner",
        where: is_nil(s.team_id),
        select: %{s | memberships: [%{user: o, role: :owner}]}
      )
      |> Repo.all(timeout: :infinity)

    log("Found #{length(sites_without_teams)} sites without teams...")

    if not dry_run? do
      teams_count = backfill_teams(sites_without_teams)

      log("Backfilled #{teams_count} teams.")
    end

    # Users on trial without team

    users_on_trial_without_team =
      from(
        u in Plausible.Auth.User,
        as: :user,
        where: not is_nil(u.trial_expiry_date),
        where:
          not exists(
            from tm in Teams.Membership,
              where: tm.role == :owner,
              where: tm.user_id == parent_as(:user).id
          )
      )
      |> Repo.all(timeout: :infinity)

    log("Found #{length(users_on_trial_without_team)} users on trial without team...")

    if not dry_run? do
      Enum.each(users_on_trial_without_team, fn user ->
        {:ok, _} = Teams.get_or_create(user)
      end)

      log("Created teams for all users on trial without a team.")
    end

    # Guest memberships with mismatched team site

    mismatched_guest_memberships_to_remove =
      from(
        gm in Teams.GuestMembership,
        inner_join: tm in assoc(gm, :team_membership),
        inner_join: s in assoc(gm, :site),
        where: tm.team_id != s.team_id
      )
      |> Repo.all()

    log(
      "Found #{length(mismatched_guest_memberships_to_remove)} guest memberships with mismatched team to remove..."
    )

    if not dry_run? do
      team_ids_to_prune = remove_guest_memberships(mismatched_guest_memberships_to_remove)

      log("Pruning guest team memberships for #{length(team_ids_to_prune)} teams...")

      from(t in Teams.Team, where: t.id in ^team_ids_to_prune)
      |> Repo.all(timeout: :infinity)
      |> Enum.each(fn team ->
        Plausible.Teams.Memberships.prune_guests(team)
      end)

      log("Guest memberships with mismatched team cleared.")
    end

    # Guest Memberships cleanup

    site_memberships_query =
      from(
        sm in "site_memberships",
        where: sm.site_id == parent_as(:guest_membership).site_id,
        where: sm.user_id == parent_as(:team_membership).user_id,
        where: sm.role != "owner",
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
      |> Repo.all(timeout: :infinity)

    log("Found #{length(guest_memberships_to_remove)} guest memberships to remove...")

    if not dry_run? do
      team_ids_to_prune = remove_guest_memberships(guest_memberships_to_remove)

      log("Pruning guest team memberships for #{length(team_ids_to_prune)} teams...")

      from(t in Teams.Team, where: t.id in ^team_ids_to_prune)
      |> Repo.all(timeout: :infinity)
      |> Enum.each(fn team ->
        Plausible.Teams.Memberships.prune_guests(team)
      end)

      log("Guest memberships cleared.")
    end

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
        sm in "site_memberships",
        as: :site_membership,
        inner_join: s in Plausible.Site,
        on: s.id == sm.site_id,
        inner_join: t in Plausible.Teams.Team,
        on: t.id == s.team_id,
        inner_join: u in Plausible.Auth.User,
        on: u.id == sm.user_id,
        where: sm.role != "owner",
        where: not exists(guest_memberships_query),
        select: %{
          user: u,
          site: %{s | team: t},
          inserted_at: sm.inserted_at,
          updated_at: sm.updated_at,
          role: sm.role
        }
      )
      |> Repo.all(timeout: :infinity)

    log(
      "Found #{length(site_memberships_to_backfill)} site memberships without guest membership..."
    )

    if not dry_run? do
      backfill_guest_memberships(site_memberships_to_backfill)

      log("Backfilled missing guest memberships.")
    end

    # Stale guest memberships sync

    stale_guest_memberships =
      from(
        sm in "site_memberships",
        inner_join: tm in Teams.Membership,
        on: tm.user_id == sm.user_id,
        inner_join: gm in Teams.GuestMembership,
        on: gm.site_id == sm.site_id,
        where: tm.role == :guest,
        where:
          (gm.role == :viewer and sm.role == "admin") or
            (gm.role == :editor and sm.role == "viewer"),
        select: {gm, sm.role}
      )
      |> Repo.all(timeout: :infinity)

    log("Found #{length(stale_guest_memberships)} guest memberships with role out of sync...")

    if not dry_run? do
      sync_guest_memberships(stale_guest_memberships)

      log("All guest memberships are up to date now.")
    end

    # Guest invitations cleanup

    site_invitations_query =
      from(
        i in "invitations",
        where: i.site_id == parent_as(:guest_invitation).site_id,
        where: i.email == parent_as(:team_invitation).email,
        where:
          (i.role == "viewer" and parent_as(:guest_invitation).role == :viewer) or
            (i.role == "admin" and parent_as(:guest_invitation).role == :editor),
        select: true
      )

    guest_invitations_to_remove =
      from(
        gi in Teams.GuestInvitation,
        as: :guest_invitation,
        inner_join: ti in assoc(gi, :team_invitation),
        as: :team_invitation,
        where: not exists(site_invitations_query)
      )
      |> Repo.all(timeout: :infinity)

    log("Found #{length(guest_invitations_to_remove)} guest invitations to remove...")

    if not dry_run? do
      team_ids_to_prune = remove_guest_invitations(guest_invitations_to_remove)

      log("Pruning guest team invitations for #{length(team_ids_to_prune)} teams...")

      from(t in Teams.Team, where: t.id in ^team_ids_to_prune)
      |> Repo.all(timeout: :infinity)
      |> Enum.each(fn team ->
        Plausible.Teams.Invitations.prune_guest_invitations(team)
      end)

      log("Guest invitations cleared.")
    end

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
        si in "invitations",
        as: :site_invitation,
        inner_join: s in Plausible.Site,
        on: si.site_id == s.id,
        inner_join: t in Teams.Team,
        on: t.id == s.team_id,
        inner_join: inv in Plausible.Auth.User,
        on: inv.id == si.inviter_id,
        where: si.role != "owner",
        where: not exists(guest_invitations_query),
        select: %{
          inserted_at: si.inserted_at,
          updated_at: si.updated_at,
          role: si.role,
          invitation_id: si.invitation_id,
          email: si.email,
          site: %{s | team: t},
          inviter: inv
        }
      )
      |> Repo.all(timeout: :infinity)

    log(
      "Found #{length(site_invitations_to_backfill)} site invitations without guest invitation..."
    )

    if not dry_run? do
      backfill_guest_invitations(site_invitations_to_backfill)

      log("Backfilled missing guest invitations.")
    end

    # Stale guest invitations sync

    stale_guest_invitations =
      from(
        si in "invitations",
        inner_join: ti in Teams.Invitation,
        on: ti.email == si.email,
        inner_join: gi in assoc(ti, :guest_invitations),
        on: gi.site_id == si.site_id,
        where: ti.role == :guest,
        where:
          (gi.role == :viewer and si.role == "admin") or
            (gi.role == :editor and si.role == "viewer") or
            is_distinct(gi.invitation_id, si.invitation_id),
        select: {gi, %{role: si.role, invitation_id: si.invitation_id}}
      )
      |> Repo.all(timeout: :infinity)

    log("Found #{length(stale_guest_invitations)} guest invitations with role out of sync...")

    if not dry_run? do
      sync_guest_invitations(stale_guest_invitations)

      log("All guest invitations are up to date now.")
    end

    # Site transfers cleanup

    site_invitations_query =
      from(
        i in "invitations",
        where: i.site_id == parent_as(:site_transfer).site_id,
        where: i.email == parent_as(:site_transfer).email,
        where: i.role == "owner",
        select: true
      )

    site_transfers_to_remove =
      from(
        st in Teams.SiteTransfer,
        as: :site_transfer,
        where: not exists(site_invitations_query)
      )
      |> Repo.all(timeout: :infinity)

    log("Found #{length(site_transfers_to_remove)} site transfers to remove...")

    if not dry_run? do
      remove_site_transfers(site_transfers_to_remove)

      log("Site transfers cleared.")
    end

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
        si in "invitations",
        as: :site_invitation,
        inner_join: s in Plausible.Site,
        on: s.id == si.site_id,
        inner_join: inv in Plausible.Auth.User,
        on: inv.id == si.inviter_id,
        where: si.role == "owner",
        where: not exists(site_transfers_query),
        select: %{
          email: si.email,
          role: si.role,
          invitation_id: si.invitation_id,
          inserted_at: si.inserted_at,
          updated_at: si.updated_at,
          site: s,
          inviter: inv
        }
      )
      |> Repo.all(timeout: :infinity)

    log(
      "Found #{length(site_invitations_to_backfill)} ownership transfers without site transfer..."
    )

    if not dry_run? do
      backfill_site_transfers(site_invitations_to_backfill)

      log("Backfilled missing site transfers.")

      log("All data are up to date now!")
    end
  end

  def delete_orphaned_teams(teams) do
    Enum.each(teams, &Repo.delete!/1)
  end

  defp backfill_teams(sites) do
    sites
    |> Enum.map(fn %{id: site_id, memberships: [%{user: owner, role: :owner}]} ->
      {owner, site_id}
    end)
    |> Enum.group_by(&elem(&1, 0), &elem(&1, 1))
    |> tap(fn
      grouped when grouped != %{} ->
        log("Teams about to be created: #{map_size(grouped)}")

        log(
          "Max sites: #{Enum.max_by(grouped, fn {_, sites} -> length(sites) end) |> elem(1) |> length()}"
        )

      _ ->
        :pass
    end)
    |> Enum.map(fn {owner, site_ids} ->
      Repo.transaction(
        fn ->
          {:ok, team} = Teams.get_or_create(owner)

          team =
            team
            |> Ecto.Changeset.change()
            |> Ecto.Changeset.put_change(:trial_expiry_date, owner.trial_expiry_date)
            |> Ecto.Changeset.force_change(:updated_at, owner.updated_at)
            |> Repo.update!()

          Repo.update_all(from(s in Plausible.Site, where: s.id in ^site_ids),
            set: [team_id: team.id]
          )
        end,
        timeout: :infinity
      )

      IO.write(".")
    end)
    |> length()
  end

  defp remove_guest_memberships(guest_memberships) do
    ids = Enum.map(guest_memberships, & &1.id)

    {_, team_ids} =
      Repo.delete_all(
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
    site_memberships
    |> Enum.group_by(&{&1.site.team, &1.user}, & &1)
    |> tap(fn
      grouped when grouped != %{} ->
        log("Team memberships to be created: #{map_size(grouped)}")

        log(
          "Max guest memberships: #{Enum.max_by(grouped, fn {_, gms} -> length(gms) end) |> elem(1) |> length()}"
        )

      _ ->
        :pass
    end)
    |> Enum.each(fn {{team, user}, site_memberships} ->
      first_site_membership =
        Enum.min_by(site_memberships, & &1.inserted_at)

      team_membership =
        team
        |> Teams.Membership.changeset(user, :guest)
        |> Ecto.Changeset.put_change(:inserted_at, first_site_membership.inserted_at)
        |> Ecto.Changeset.put_change(:updated_at, first_site_membership.updated_at)
        |> Repo.insert!(
          on_conflict: [set: [updated_at: first_site_membership.updated_at]],
          conflict_target: [:team_id, :user_id]
        )

      Enum.each(site_memberships, fn site_membership ->
        team_membership
        |> Teams.GuestMembership.changeset(
          site_membership.site,
          translate_role(site_membership.role)
        )
        |> Ecto.Changeset.put_change(:inserted_at, site_membership.inserted_at)
        |> Ecto.Changeset.put_change(:updated_at, site_membership.updated_at)
        |> Repo.insert!()
      end)

      IO.write(".")
    end)
  end

  defp sync_guest_memberships(guest_memberships_and_roles) do
    Enum.each(guest_memberships_and_roles, fn {guest_membership, role} ->
      guest_membership
      |> Ecto.Changeset.change(role: translate_role(role))
      |> Ecto.Changeset.put_change(:updated_at, guest_membership.updated_at)
      |> Repo.update!()

      IO.write(".")
    end)
  end

  defp remove_guest_invitations(guest_invitations) do
    ids = Enum.map(guest_invitations, & &1.id)

    {_, team_ids} =
      Repo.delete_all(
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
    |> Enum.group_by(&{&1.site.team, &1.email}, & &1)
    |> Enum.each(fn {{team, email}, site_invitations} ->
      first_site_invitation = List.first(site_invitations)

      team_invitation =
        team
        # NOTE: we put first inviter and invitation ID matching team/email combination
        |> Teams.Invitation.changeset(
          email: email,
          role: :guest,
          inviter: first_site_invitation.inviter
        )
        |> Ecto.Changeset.put_change(:inserted_at, first_site_invitation.inserted_at)
        |> Ecto.Changeset.put_change(:updated_at, first_site_invitation.updated_at)
        |> Repo.insert!(
          on_conflict: [set: [updated_at: first_site_invitation.updated_at]],
          conflict_target: [:team_id, :email]
        )

      Enum.each(site_invitations, fn site_invitation ->
        team_invitation
        |> Teams.GuestInvitation.changeset(
          site_invitation.site,
          translate_role(site_invitation.role)
        )
        |> Ecto.Changeset.put_change(:invitation_id, site_invitation.invitation_id)
        |> Ecto.Changeset.put_change(:inserted_at, site_invitation.inserted_at)
        |> Ecto.Changeset.put_change(:updated_at, site_invitation.updated_at)
        |> Repo.insert!()
      end)

      IO.write(".")
    end)
  end

  defp sync_guest_invitations(guest_and_site_invitations) do
    Enum.each(guest_and_site_invitations, fn {guest_invitation, site_invitation} ->
      guest_invitation
      |> Ecto.Changeset.change()
      |> Ecto.Changeset.put_change(:role, translate_role(site_invitation.role))
      |> Ecto.Changeset.put_change(:invitation_id, site_invitation.invitation_id)
      |> Ecto.Changeset.put_change(:updated_at, guest_invitation.updated_at)
      |> Repo.update!()

      IO.write(".")
    end)
  end

  defp remove_site_transfers(site_transfers) do
    ids = Enum.map(site_transfers, & &1.id)

    Repo.delete_all(from(st in Teams.SiteTransfer, where: st.id in ^ids))
  end

  defp backfill_site_transfers(site_invitations) do
    Enum.each(site_invitations, fn site_invitation ->
      site_invitation.site
      |> Teams.SiteTransfer.changeset(
        initiator: site_invitation.inviter,
        email: site_invitation.email
      )
      |> Ecto.Changeset.put_change(:transfer_id, site_invitation.invitation_id)
      |> Ecto.Changeset.put_change(:inserted_at, site_invitation.inserted_at)
      |> Ecto.Changeset.put_change(:updated_at, site_invitation.updated_at)
      |> Repo.insert!()

      IO.write(".")
    end)
  end

  defp translate_role("admin"), do: :editor
  defp translate_role("viewer"), do: :viewer

  defp log(msg) do
    IO.puts("[#{DateTime.utc_now(:second)}] #{msg}")
  end

  defp totp_vault_key() do
    :plausible
    |> Application.fetch_env!(Plausible.Auth.TOTP)
    |> Keyword.fetch!(:vault_key)
  end
end
