defmodule Plausible.Teams.Management.Layout do
  @moduledoc """
  Abstraction for team membership(s) layout - provides a high level CRUD for
  setting up team memberships, including invitations. Persisting the layout,
  effectively takes care of delegating the operations to specialized services
  and sending out e-mail notifications on success, if need be.
  To be used in UIs allowing team memberships adjustments.
  """
  alias Plausible.Teams
  alias Plausible.Teams.Management.Layout.Entry
  alias Plausible.Repo
  alias Plausible.Auth.User

  @type t() :: %{String.t() => Entry.t()}

  @spec init(Teams.Team.t()) :: t()
  def init(%Teams.Team{} = team) do
    invitations_sent = Teams.Invitations.all(team)
    all_members = Teams.Memberships.all(team)
    build_by_email(invitations_sent ++ all_members)
  end

  @spec build_by_email([Teams.Invitation.t() | Teams.Membership.t()]) ::
          t()
  def build_by_email(entities) do
    Enum.reduce(entities, %{}, fn
      %Teams.Invitation{} = invitation, acc ->
        Map.put(acc, invitation.email, Entry.new(invitation))

      %Teams.Membership{} = membership, acc ->
        Map.put(
          acc,
          membership.user.email,
          Entry.new(membership)
        )
    end)
  end

  @spec active_count(t()) :: non_neg_integer()
  def active_count(layout) do
    Enum.count(layout, fn {_, entry} -> entry.queued_op != :delete end)
  end

  @spec owners_count(t()) :: non_neg_integer()
  def owners_count(layout) do
    Enum.count(layout, fn {_, entry} -> entry.queued_op != :delete and entry.role == :owner end)
  end

  @spec has_guests?(t()) :: boolean()
  def has_guests?(layout) do
    not is_nil(
      Enum.find(
        layout,
        fn
          {_, entry} -> entry.role == :guest and entry.queued_op != :delete
        end
      )
    )
  end

  @spec update_role(t(), String.t(), atom()) :: t()
  def update_role(layout, email, role) do
    entry = Map.fetch!(layout, email)
    Map.put(layout, email, Entry.patch(entry, role: role, queued_op: :update))
  end

  @spec schedule_send(t(), String.t(), atom(), Keyword.t()) :: t()
  def schedule_send(layout, email, role, entry_attrs \\ []) do
    invitation = %Teams.Invitation{email: email, role: role}
    Map.put(layout, email, Entry.new(invitation, Keyword.merge(entry_attrs, queued_op: :send)))
  end

  @spec schedule_delete(t(), String.t()) :: t()
  def schedule_delete(layout, email) do
    entry = Map.fetch!(layout, email)
    Map.put(layout, email, Entry.patch(entry, queued_op: :delete))
  end

  @spec verify_removable(t(), String.t()) :: :ok | {:error, String.t()}
  def verify_removable(layout, email) do
    ensure_at_least_one_owner(layout, email)
  end

  @spec removable?(t(), String.t()) :: boolean()
  def removable?(layout, email) do
    verify_removable(layout, email) == :ok
  end

  @spec sorted_for_display(t()) :: [{String.t(), Entry.t()}]
  def sorted_for_display(layout) do
    layout
    |> Enum.reject(fn {_, entry} -> entry.queued_op == :delete end)
    |> Enum.sort_by(fn {email, entry} ->
      primary_criterion =
        case entry do
          %{role: :guest, type: :invitation_pending} -> 10
          %{role: :guest, type: :invitation_sent} -> 11
          %{role: :guest, type: :membership} -> 12
          %{type: :invitation_pending} -> 0
          %{type: :invitation_sent} -> 1
          %{type: :membership} -> 2
        end

      secondary_criterion = entry.name
      tertiary_criterion = email
      {primary_criterion, secondary_criterion, tertiary_criterion}
    end)
  end

  @spec persist(t(), %{current_user: User.t(), current_team: Teams.Team.t()}) ::
          {:ok, integer()} | {:error, any()}
  def persist(layout, context) do
    result =
      Repo.transaction(fn ->
        Teams.complete_setup(context.current_team)

        layout
        |> sorted_for_persistence()
        |> Enum.reduce([], fn {_, entry}, acc ->
          persist_entry(entry, context, acc)
        end)
      end)

    case result do
      {:ok, persisted} ->
        persisted
        |> Enum.each(fn
          {%Entry{type: :invitation_pending}, invitation} ->
            invitee = Plausible.Auth.find_user_by(email: invitation.email)
            Teams.Invitations.InviteToTeam.send_invitation_email(invitation, invitee)

          {%Entry{type: :membership, queued_op: :delete}, team_membership} ->
            Teams.Memberships.Remove.send_team_member_removed_email(team_membership)

          _ ->
            :noop
        end)

        {:ok, length(persisted)}

      {:error, _} = error ->
        error
    end
  end

  defp sorted_for_persistence(layout) do
    # sort by deletions first, so team member limits are triggered accurately
    Enum.sort_by(layout, fn {_email, entry} ->
      case entry.queued_op do
        :delete -> 0
        _ -> 1
      end
    end)
  end

  defp ensure_at_least_one_owner(layout, email) do
    if Enum.find(layout, fn {_email, entry} ->
         entry.email != email and
           entry.role == :owner and
           entry.type == :membership and
           entry.queued_op != :delete
       end),
       do: :ok,
       else: {:error, "The team has to have at least one owner"}
  end

  def persist_entry(entry, context, acc) do
    case Entry.persist(entry, context) do
      {:ok, :ignore} -> acc
      {:ok, persist_result} -> [{entry, persist_result} | acc]
      {:error, error} -> Repo.rollback(error)
    end
  end
end
