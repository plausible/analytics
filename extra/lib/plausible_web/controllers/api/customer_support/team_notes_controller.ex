defmodule PlausibleWeb.Api.CustomerSupport.TeamNotesController do
  @moduledoc """
  Replaces a team's notes, as the Notes field on the CS admin team page does.

  The request carries the notes it expects to replace (`previous_notes`), so
  a note someone else added in the meantime is never overwritten unseen.
  """
  use PlausibleWeb, :controller
  use Plausible.Repo

  alias PlausibleWeb.Api.CustomerSupport.Helpers, as: H

  @max_length 10_000

  def update(conn, params) do
    H.run_team_action(conn, params, "team_notes_updated", fn team ->
      notes = params["notes"]

      with :ok <- H.guard(is_binary(notes), "Parameter `notes` is required"),
           :ok <- H.guard(String.length(notes) <= @max_length, "The notes are too long"),
           :ok <-
             H.guard(
               blank(params["previous_notes"]) == blank(team.notes),
               "The team's notes changed since they were read; read them again"
             ),
           {:ok, team} <- team |> Ecto.Changeset.change(notes: notes) |> Repo.update() do
        {:ok, team, %{notes: team.notes}}
      end
    end)
  end

  defp blank(nil), do: ""
  defp blank(notes) when is_binary(notes), do: String.trim(notes)
  defp blank(_), do: :invalid
end
