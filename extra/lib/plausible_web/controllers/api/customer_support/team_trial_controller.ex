defmodule PlausibleWeb.Api.CustomerSupport.TeamTrialController do
  @moduledoc """
  Trial dates, blocking a trial and the next-upgrade override, as on the CS
  admin Overview tab. Only the named fields change.
  """
  use PlausibleWeb, :controller
  use Plausible.Repo

  alias Plausible.Billing.SiteLocker
  alias PlausibleWeb.Api.CustomerSupport.Helpers, as: H

  @doc """
  Sets both trial dates at once. Unlike the CS admin form (`crm_changeset`),
  it doesn't bump Accept traffic Until when the expiry changes: both dates
  are given explicitly.
  """
  def extend(conn, params) do
    H.run_team_action(conn, params, "trial_extended", fn team ->
      with {:ok, expiry} <- parse_date(params["trial_expiry_date"]),
           {:ok, accept_until} <- parse_date(params["accept_traffic_until"]),
           :ok <-
             H.guard(later?(expiry, team.trial_expiry_date), "The new expiry date isn't later"),
           :ok <-
             H.guard(
               later?(accept_until, team.accept_traffic_until),
               "The new Accept traffic Until date isn't later"
             ),
           :ok <-
             H.guard(
               Date.compare(accept_until, expiry) != :lt,
               "Accept traffic Until can't be before the expiry date"
             ),
           {:ok, team} <-
             team
             |> Ecto.Changeset.change(
               trial_expiry_date: expiry,
               accept_traffic_until: accept_until
             )
             |> Repo.update() do
        Plausible.Teams.refresh_lock_and_deletion_schedule(team)

        {:ok, team, %{trial_expiry_date: expiry, accept_traffic_until: accept_until}}
      end
    end)
  end

  @doc "Ends a trial today and stops accepting traffic, with a note why."
  def block(conn, params) do
    H.run_team_action(conn, params, "trial_blocked", fn team ->
      today = Date.utc_today()
      note = if is_binary(params["note"]), do: String.trim(params["note"]), else: ""

      with :ok <- H.guard(is_nil(team.subscription), "The team has or had a subscription"),
           :ok <- check_note_line(note, "note"),
           {:ok, team} <-
             team
             |> Ecto.Changeset.change(
               trial_expiry_date: today,
               accept_traffic_until: today,
               notes: append_note_line(team.notes, "#{today}: trial blocked: #{note}")
             )
             |> Repo.update() do
        SiteLocker.update_for(team)
        {:ok, team, %{trial_expiry_date: today, accept_traffic_until: today}}
      end
    end)
  end

  def upgrade_override(conn, params) do
    H.run_team_action(conn, params, "upgrade_override_allowed", fn team ->
      with :ok <- H.guard(not team.allow_next_upgrade_override, "The override is already on"),
           {:ok, team} <-
             team
             |> Ecto.Changeset.change(allow_next_upgrade_override: true)
             |> Repo.update() do
        {:ok, team, %{allow_next_upgrade_override: true}}
      end
    end)
  end

  defp parse_date(value) when is_binary(value) do
    case Date.from_iso8601(value) do
      {:ok, date} -> {:ok, date}
      _ -> {:error, :guard, "Dates must be YYYY-MM-DD"}
    end
  end

  defp parse_date(_), do: {:error, :guard, "Dates must be YYYY-MM-DD"}

  @max_note_line_length 500

  # A line for the team notes: present, a single line, up to 500 characters.
  defp check_note_line(line, param) do
    with :ok <- H.guard(line != "", "Parameter `#{param}` is required"),
         :ok <- H.guard(not String.contains?(line, ["\n", "\r"]), "One line only") do
      H.guard(String.length(line) <= @max_note_line_length, "The line is too long")
    end
  end

  defp append_note_line(nil, line), do: line
  defp append_note_line("", line), do: line
  defp append_note_line(notes, line), do: notes <> "\n" <> line

  defp later?(_new, nil), do: true
  defp later?(new, current), do: Date.after?(new, current)
end
