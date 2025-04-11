defmodule Plausible.DataMigration.BackfillTeams do
  @moduledoc """
  Backfill and sync all teams related entities.
  """

  import Ecto.Query

  alias Plausible.Repo

  defmacrop is_distinct(f1, f2) do
    quote do
      fragment("? IS DISTINCT FROM ?", unquote(f1), unquote(f2))
    end
  end

  def run(opts \\ []) do
    dry_run? = Keyword.get(opts, :dry_run?, true)
    Repo.transaction(fn -> backfill(dry_run?) end, timeout: :infinity)
  end

  defp backfill(dry_run?) do
    # Orphaned teams

    orphaned_teams =
      from(
        t in "teams",
        left_join: tm in "team_memberships",
        on: tm.team_id == t.id,
        left_join: s in "sites",
        on: s.team_id == t.id,
        where: is_nil(tm.id),
        where: is_nil(s.id),
        select: %{id: t.id}
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
        s in "sites",
        inner_join: m in "site_memberships",
        on: m.site_id == s.id,
        inner_join: o in "users",
        on: o.id == m.user_id,
        where: m.role == "owner",
        where: is_nil(s.team_id),
        select: %{
          id: s.id,
          owner_id: o.id
        }
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
        u in "users",
        as: :user,
        where: not is_nil(u.trial_expiry_date),
        where:
          not exists(
            from tm in "team_memberships",
              where: tm.role == "owner",
              where: tm.user_id == parent_as(:user).id,
              select: 1
          ),
        select: u.id
      )
      |> Repo.all(timeout: :infinity)

    log("Found #{length(users_on_trial_without_team)} users on trial without team...")

    if not dry_run? do
      Enum.each(users_on_trial_without_team, fn user_id ->
        create_personal_team(user_id)
      end)

      log("Created teams for all users on trial without a team.")
    end

    # Guest memberships with mismatched team site

    mismatched_guest_memberships_to_remove =
      from(
        gm in "guest_memberships",
        inner_join: tm in "team_memberships",
        on: tm.id == gm.team_membership_id,
        inner_join: s in "sites",
        on: s.id == gm.site_id,
        where: tm.team_id != s.team_id,
        select: gm.id
      )
      |> Repo.all()

    log(
      "Found #{length(mismatched_guest_memberships_to_remove)} guest memberships with mismatched team to remove..."
    )

    if not dry_run? do
      team_ids_to_prune = remove_guest_memberships(mismatched_guest_memberships_to_remove)

      log("Pruning guest team memberships for #{length(team_ids_to_prune)} teams...")

      Enum.each(team_ids_to_prune, fn team_id ->
        prune_guests(team_id)
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
        gm in "guest_memberships",
        as: :guest_membership,
        inner_join: tm in "team_memberships",
        on: tm.id == gm.team_membership_id,
        as: :team_membership,
        where: not exists(site_memberships_query),
        select: gm.id
      )
      |> Repo.all(timeout: :infinity)

    log("Found #{length(guest_memberships_to_remove)} guest memberships to remove...")

    if not dry_run? do
      team_ids_to_prune = remove_guest_memberships(guest_memberships_to_remove)

      log("Pruning guest team memberships for #{length(team_ids_to_prune)} teams...")

      Enum.each(team_ids_to_prune, fn team ->
        prune_guests(team.id)
      end)

      log("Guest memberships cleared.")
    end

    # Guest Memberships backfill

    guest_memberships_query =
      from(
        gm in "guest_memberships",
        inner_join: tm in "team_memberships",
        on: tm.id == gm.team_membership_id,
        where: gm.site_id == parent_as(:site_membership).site_id,
        where: tm.user_id == parent_as(:site_membership).user_id,
        select: 1
      )

    site_memberships_to_backfill =
      from(
        sm in "site_memberships",
        as: :site_membership,
        inner_join: s in "sites",
        on: s.id == sm.site_id,
        inner_join: t in "teams",
        on: t.id == s.team_id,
        inner_join: u in "users",
        on: u.id == sm.user_id,
        where: sm.role != "owner",
        where: not exists(guest_memberships_query),
        select: %{
          user_id: u.id,
          site_id: s.id,
          team_id: t.id,
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
        inner_join: tm in "team_memberships",
        on: tm.user_id == sm.user_id,
        inner_join: gm in "guest_memberships",
        on: gm.site_id == sm.site_id,
        where: tm.role == "guest",
        where:
          (gm.role == "viewer" and sm.role == "admin") or
            (gm.role == "editor" and sm.role == "viewer"),
        select: {gm.id, sm.role}
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
          (i.role == "viewer" and parent_as(:guest_invitation).role == "viewer") or
            (i.role == "admin" and parent_as(:guest_invitation).role == "editor"),
        select: true
      )

    guest_invitations_to_remove =
      from(
        gi in "guest_invitations",
        as: :guest_invitation,
        inner_join: ti in "team_invitations",
        on: ti.id == gi.team_invitation_id,
        as: :team_invitation,
        where: not exists(site_invitations_query),
        select: gi.id
      )
      |> Repo.all(timeout: :infinity)

    log("Found #{length(guest_invitations_to_remove)} guest invitations to remove...")

    if not dry_run? do
      team_ids_to_prune = remove_guest_invitations(guest_invitations_to_remove)

      log("Pruning guest team invitations for #{length(team_ids_to_prune)} teams...")

      Enum.each(team_ids_to_prune, fn team_id ->
        prune_guest_invitations(team_id)
      end)

      log("Guest invitations cleared.")
    end

    # Guest invitations backfill

    guest_invitations_query =
      from(
        gi in "guest_invitations",
        inner_join: ti in "team_invitations",
        on: ti.id == gi.team_invitation_id,
        where: gi.site_id == parent_as(:site_invitation).site_id,
        where: ti.email == parent_as(:site_invitation).email,
        select: 1
      )

    site_invitations_to_backfill =
      from(
        si in "invitations",
        as: :site_invitation,
        inner_join: s in "sites",
        on: si.site_id == s.id,
        inner_join: t in "teams",
        on: t.id == s.team_id,
        inner_join: inv in "users",
        on: inv.id == si.inviter_id,
        where: si.role != "owner",
        where: not exists(guest_invitations_query),
        select: %{
          inserted_at: si.inserted_at,
          updated_at: si.updated_at,
          role: si.role,
          invitation_id: si.invitation_id,
          email: si.email,
          site_id: s.id,
          team_id: t.id,
          inviter_id: inv.id
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
        inner_join: ti in "team_invitations",
        on: ti.email == si.email,
        inner_join: gi in "guest_invitations",
        on: gi.team_invitation_id == ti.id,
        on: gi.site_id == si.site_id,
        where: ti.role == "guest",
        where:
          (gi.role == "viewer" and si.role == "admin") or
            (gi.role == "editor" and si.role == "viewer") or
            is_distinct(gi.invitation_id, si.invitation_id),
        select: {gi.id, %{role: si.role, invitation_id: si.invitation_id}}
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
        st in "team_site_transfers",
        as: :site_transfer,
        where: not exists(site_invitations_query),
        select: st.id
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
        st in "team_site_transfers",
        where: st.site_id == parent_as(:site_invitation).site_id,
        where: st.email == parent_as(:site_invitation).email,
        select: 1
      )

    site_invitations_to_backfill =
      from(
        si in "invitations",
        as: :site_invitation,
        inner_join: s in "sites",
        on: s.id == si.site_id,
        inner_join: inv in "users",
        on: inv.id == si.inviter_id,
        where: si.role == "owner",
        where: not exists(site_transfers_query),
        select: %{
          email: si.email,
          invitation_id: si.invitation_id,
          inserted_at: si.inserted_at,
          updated_at: si.updated_at,
          site_id: s.id,
          inviter_id: inv.id
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
    ids = Enum.map(teams, & &1.id)
    Repo.delete_all(from(t in "teams", where: t.id in ^ids))
  end

  defp backfill_teams(sites) do
    sites
    |> Enum.map(fn %{id: site_id, owner_id: owner_id} ->
      {owner_id, site_id}
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
    |> Enum.map(fn {owner_id, site_ids} ->
      Repo.transaction(
        fn ->
          {user_id, trial_expiry_date, updated_at} =
            from(
              u in "users",
              where: u.id == ^owner_id,
              select: {u.id, u.trial_expiry_date, u.updated_at}
            )
            |> Repo.one!()

          team = create_personal_team(user_id)

          Repo.update_all(
            from(t in "teams", where: t.id == ^team.id),
            set: [
              trial_expiry_date: trial_expiry_date,
              updated_at: updated_at
            ]
          )

          Repo.update_all(from(s in "sites", where: s.id in ^site_ids),
            set: [team_id: team.id]
          )
        end,
        timeout: :infinity
      )

      IO.write(".")
    end)
    |> length()
  end

  defp remove_guest_memberships(guest_membership_ids) do
    {_, team_ids} =
      Repo.delete_all(
        from(
          gm in "guest_memberships",
          inner_join: tm in "team_memberships",
          on: tm.id == gm.team_membership_id,
          where: gm.id in ^guest_membership_ids,
          select: tm.team_id
        )
      )

    Enum.uniq(team_ids)
  end

  defp backfill_guest_memberships(site_memberships) do
    site_memberships
    |> Enum.group_by(&{&1.team_id, &1.user_id}, & &1)
    |> tap(fn
      grouped when grouped != %{} ->
        log("Team memberships to be created: #{map_size(grouped)}")

        log(
          "Max guest memberships: #{Enum.max_by(grouped, fn {_, gms} -> length(gms) end) |> elem(1) |> length()}"
        )

      _ ->
        :pass
    end)
    |> Enum.each(fn {{team_id, user_id}, site_memberships} ->
      first_site_membership =
        Enum.min_by(site_memberships, & &1.inserted_at)

      team_membership_data = %{
        team_id: team_id,
        user_id: user_id,
        role: "guest",
        is_autocreated: false,
        inserted_at: first_site_membership.inserted_at,
        updated_at: first_site_membership.updated_at
      }

      {_, [team_membership]} =
        Repo.insert_all(
          "team_memberships",
          [team_membership_data],
          returning: [:id],
          on_conflict: [set: [updated_at: first_site_membership.updated_at]],
          conflict_target: [:team_id, :user_id]
        )

      Enum.each(site_memberships, fn site_membership ->
        guest_membership_data = %{
          team_membership_id: team_membership.id,
          site_id: site_membership.site_id,
          role: translate_role(site_membership.role),
          inserted_at: site_membership.inserted_at,
          updated_at: site_membership.updated_at
        }

        Repo.insert_all("guest_memberships", [guest_membership_data])
      end)

      IO.write(".")
    end)
  end

  defp sync_guest_memberships(guest_memberships_and_roles) do
    Enum.each(guest_memberships_and_roles, fn {guest_membership_id, role} ->
      Repo.update_all(
        from(gm in "guest_memberships", where: gm.id == ^guest_membership_id),
        set: [role: translate_role(role)]
      )

      IO.write(".")
    end)
  end

  defp remove_guest_invitations(guest_invitation_ids) do
    {_, team_ids} =
      Repo.delete_all(
        from(
          gi in "guest_invitations",
          inner_join: ti in "team_invitations",
          on: ti.id == gi.team_invitation_id,
          where: gi.id in ^guest_invitation_ids,
          select: ti.team_id
        )
      )

    Enum.uniq(team_ids)
  end

  defp backfill_guest_invitations(site_invitations) do
    site_invitations
    |> Enum.group_by(&{&1.team_id, &1.email}, & &1)
    |> Enum.each(fn {{team_id, email}, site_invitations} ->
      first_site_invitation = List.first(site_invitations)

      team_invitation_data = %{
        invitation_id: Nanoid.generate(),
        email: email,
        role: "guest",
        inviter_id: first_site_invitation.inviter_id,
        team_id: team_id,
        inserted_at: first_site_invitation.inserted_at,
        updated_at: first_site_invitation.updated_at
      }

      {_, [team_invitation]} =
        Repo.insert_all(
          "team_invitations",
          [team_invitation_data],
          on_conflict: [set: [updated_at: first_site_invitation.updated_at]],
          conflict_target: [:team_id, :email],
          returning: [:id]
        )

      Enum.each(site_invitations, fn site_invitation ->
        guest_invitation_data = %{
          invitation_id: site_invitation.invitation_id,
          role: translate_role(site_invitation.role),
          site_id: site_invitation.site_id,
          team_invitation_id: team_invitation.id,
          inserted_at: site_invitation.inserted_at,
          updated_at: site_invitation.updated_at
        }

        Repo.insert_all("guest_invitations", [guest_invitation_data])
      end)

      IO.write(".")
    end)
  end

  defp sync_guest_invitations(guest_and_site_invitations) do
    Enum.each(guest_and_site_invitations, fn {guest_invitation_id, site_invitation} ->
      Repo.update_all(
        from(gi in "guest_invitations", where: gi.id == ^guest_invitation_id),
        set: [
          role: translate_role(site_invitation.role),
          invitation_id: site_invitation.invitation_id
        ]
      )

      IO.write(".")
    end)
  end

  defp remove_site_transfers(site_transfer_ids) do
    Repo.delete_all(from(st in "team_site_transfers", where: st.id in ^site_transfer_ids))
  end

  defp backfill_site_transfers(site_invitations) do
    Enum.each(site_invitations, fn site_invitation ->
      site_transfer_data = %{
        initiator: site_invitation.inviter_id,
        email: site_invitation.email,
        site_id: site_invitation.site_id,
        transfer_id: site_invitation.invitation_id,
        inserted_at: site_invitation.inserted_at,
        updated_at: site_invitation.updated_at
      }

      Repo.insert_all("team_site_transfers", [site_transfer_data])

      IO.write(".")
    end)
  end

  defp translate_role("admin"), do: "editor"
  defp translate_role("viewer"), do: "viewer"

  defp log(msg) do
    IO.puts("[#{DateTime.utc_now(:second)}] #{msg}")
  end

  defp create_personal_team(user_id) do
    trial_expiry_date = Date.shift(Date.utc_today(), year: 100)

    team_data =
      %{
        identifier: Ecto.UUID.generate() |> Ecto.UUID.dump!(),
        name: "My Personal Sites",
        trial_expiry_date: trial_expiry_date,
        accept_traffic_until: Date.add(trial_expiry_date, 14),
        hourly_api_request_limit: 1_000_000,
        allow_next_upgrade_override: false,
        locked: false,
        setup_complete: false,
        inserted_at: NaiveDateTime.utc_now(),
        updated_at: NaiveDateTime.utc_now()
      }

    {1, [team]} = Repo.insert_all("teams", [team_data], returning: [:id])

    team_membership_data = %{
      team_id: team.id,
      user_id: user_id,
      role: "owner",
      is_autocreated: true,
      inserted_at: NaiveDateTime.utc_now(),
      updated_at: NaiveDateTime.utc_now()
    }

    {1, _} = Repo.insert_all("team_memberships", [team_membership_data])

    team
  end

  defp prune_guests(team_id) do
    guest_query =
      from(
        gm in "guest_memberships",
        where: gm.team_membership_id == parent_as(:team_membership).id,
        select: true
      )

    Repo.delete_all(
      from(
        tm in "team_memberships",
        as: :team_membership,
        where: tm.team_id == ^team_id and tm.role == "guest",
        where: not exists(guest_query)
      )
    )
  end

  defp prune_guest_invitations(team_id) do
    guest_query =
      from(
        gi in "guest_invitations",
        where: gi.team_invitation_id == parent_as(:team_invitation).id,
        select: true
      )

    Repo.delete_all(
      from(
        ti in "team_invitations",
        as: :team_invitation,
        where: ti.team_id == ^team_id and ti.role == "guest",
        where: not exists(guest_query)
      )
    )
  end
end
