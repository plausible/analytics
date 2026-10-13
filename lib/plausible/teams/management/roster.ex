defmodule Plausible.Teams.Management.Roster do
  @moduledoc """
  Read-only list of a team's members and pending invitations, keyed by e-mail,
  for rendering the team management screen.
  """

  alias Plausible.Teams
  alias Plausible.Teams.Management.Roster.Entry

  @type t() :: %{String.t() => Entry.t()}

  @spec init(Teams.Team.t()) :: t()
  def init(%Teams.Team{} = team) do
    invitations = Teams.Invitations.pending_team_invitations_for(team)
    memberships = Teams.Memberships.all(team)
    build_by_email(invitations ++ memberships)
  end

  @spec build_by_email([Teams.Invitation.t() | Teams.Membership.t()]) :: t()
  def build_by_email(entities) do
    Map.new(entities, fn entity ->
      entry = Entry.new(entity)
      {entry.email, entry}
    end)
  end

  @spec owners_count(t()) :: non_neg_integer()
  def owners_count(roster) do
    Enum.count(roster, fn {_, entry} -> entry.role == :owner end)
  end

  @spec has_guests?(t()) :: boolean()
  def has_guests?(roster) do
    Enum.any?(roster, fn {_, entry} -> entry.role == :guest end)
  end

  @doc """
  Whether the entry can be removed without leaving the team without an owner.
  Only a hint for rendering: the services doing the removal check this again.
  """
  @spec removable?(t(), String.t()) :: boolean()
  def removable?(roster, email) do
    Enum.any?(roster, fn {_, entry} ->
      entry.email != email and entry.role == :owner and not Entry.invitation?(entry)
    end)
  end

  @spec sorted_for_display(t()) :: [{String.t(), Entry.t()}]
  def sorted_for_display(roster) do
    Enum.sort_by(roster, fn {email, entry} ->
      primary_criterion =
        case {entry.role, Entry.invitation?(entry)} do
          {:guest, true} -> 11
          {:guest, false} -> 12
          {_, true} -> 1
          {_, false} -> 2
        end

      {primary_criterion, entry.name, email}
    end)
  end
end
