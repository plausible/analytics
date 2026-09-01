defmodule PlausibleWeb.CustomerSupport.Team.Components.Overview do
  @moduledoc """
  Team overview component - handles team basic info, trial dates, notes
  """
  use PlausibleWeb, :live_component
  import PlausibleWeb.CustomerSupport.Live

  alias Plausible.TeamDeletionSchedules

  def update(%{team: team}, socket) do
    changeset = Plausible.Teams.Team.crm_changeset(team, %{})
    form = to_form(changeset)
    schedule = TeamDeletionSchedules.active_schedule_for_team(team)

    {:ok, assign(socket, team: team, form: form, schedule: schedule)}
  end

  def render(assigns) do
    ~H"""
    <div class="mt-8">
      <.deletion_schedule :if={@schedule} schedule={@schedule} myself={@myself} />

      <.form :let={f} for={@form} phx-submit="save-team" phx-target={@myself}>
        <.input field={f[:trial_expiry_date]} type="date" label="Trial Expiry Date" />
        <.input field={f[:accept_traffic_until]} type="date" label="Accept traffic Until" />
        <.input
          type="checkbox"
          field={f[:allow_next_upgrade_override]}
          label="Allow Next Upgrade Override"
        />

        <.input type="textarea" field={f[:notes]} label="Notes" />

        <div class="flex justify-between">
          <.button type="submit">
            Save
          </.button>

          <.button
            phx-target={@myself}
            phx-click="delete-team"
            data-confirm="Are you sure you want to delete this team?"
            theme="danger"
          >
            Delete Team
          </.button>
        </div>
      </.form>
    </div>
    """
  end

  attr :schedule, :any, required: true
  attr :myself, :any, required: true

  defp deletion_schedule(assigns) do
    ~H"""
    <div class="mb-6">
      <.notice theme={notice_theme(@schedule.status)} title="Deletion scheduled">
        {deletion_sentence(@schedule)}

        <div :if={@schedule.status == :snoozed} class="mt-3">
          <p class="text-sm text-gray-600 dark:text-gray-400">
            Snoozed until
            <strong>{@schedule.snoozed_until}</strong><span :if={@schedule.snooze_note}> — "{@schedule.snooze_note}"</span>.
          </p>

          <.button
            class="mt-2"
            phx-click="unsnooze-schedule"
            phx-target={@myself}
            data-confirm="Resume the deletion schedule now? This restarts the notice cycle."
          >
            Unsnooze
          </.button>
        </div>

        <form
          :if={@schedule.status != :snoozed}
          phx-submit="snooze-schedule"
          phx-target={@myself}
          class="mt-3 flex items-end gap-x-4"
        >
          <.input type="date" name="until" value="" label="Snooze until" />
          <.input type="text" name="note" value="" label="Note (optional)" />
          <.button type="submit">Snooze</.button>
        </form>
      </.notice>
    </div>
    """
  end

  defp notice_theme(:snoozed), do: :gray
  defp notice_theme(_), do: :yellow

  defp deletion_sentence(schedule) do
    category =
      case schedule.category do
        :expired_trial -> "expired trial"
        :churned_subscription -> "churned subscription"
      end

    status_detail =
      case schedule.status do
        :scheduled ->
          "Pending. First notice due #{schedule.first_notice_due_date}."

        :first_notice_sent ->
          "First notice sent #{format_dt(schedule.first_notice_sent_at)}."

        :reminder_sent ->
          "Reminder sent #{format_dt(schedule.reminder_sent_at)}."

        :snoozed ->
          "Snoozed."

        :cancelled ->
          "Cancelled."

        :completed ->
          "Completed."
      end

    "#{String.capitalize(category)}. Stats deletion on #{schedule.deletion_date}. #{status_detail}"
  end

  defp format_dt(nil), do: "N/A"
  defp format_dt(%NaiveDateTime{} = dt), do: NaiveDateTime.to_date(dt) |> Date.to_string()

  def handle_event("save-team", %{"team" => params}, socket) do
    changeset = Plausible.Teams.Team.crm_changeset(socket.assigns.team, params)

    case Plausible.Repo.update(changeset) do
      {:ok, team} ->
        # Prolonging trial_expiry_date (or otherwise making the team
        # eligible again) cancels any pending deletion schedule.
        TeamDeletionSchedules.cancel_for_team(team)
        schedule = TeamDeletionSchedules.active_schedule_for_team(team)

        success("Team saved")
        {:noreply, assign(socket, team: team, form: to_form(changeset), schedule: schedule)}

      {:error, changeset} ->
        failure("Error saving team: #{inspect(changeset.errors)}")
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  def handle_event("delete-team", _params, socket) do
    case Plausible.Teams.delete(socket.assigns.team) do
      {:ok, :deleted} ->
        navigate_with_success(Routes.customer_support_path(socket, :index), "Team deleted")
        {:noreply, socket}

      {:error, :active_subscription} ->
        failure("The team has an active subscription which must be canceled first.")

        {:noreply, socket}
    end
  end

  def handle_event("snooze-schedule", %{"until" => until_str} = params, socket) do
    case Date.from_iso8601(until_str) do
      {:ok, until_date} ->
        note =
          case params |> Map.get("note", "") |> String.trim() do
            "" -> nil
            note -> note
          end

        case TeamDeletionSchedules.snooze(socket.assigns.schedule, until_date, note: note) do
          {:ok, schedule} ->
            success("Deletion snoozed until #{until_date}")
            {:noreply, assign(socket, schedule: schedule)}

          {:error, {:invalid_transition, _, _}} ->
            failure("Could not snooze - schedule is no longer in a snoozable state")
            {:noreply, socket}
        end

      {:error, _} ->
        failure("Invalid date")
        {:noreply, socket}
    end
  end

  def handle_event("unsnooze-schedule", _params, socket) do
    case TeamDeletionSchedules.unsnooze(socket.assigns.schedule) do
      {:ok, schedule} ->
        success("Deletion schedule resumed")
        {:noreply, assign(socket, schedule: schedule)}

      {:error, {:invalid_transition, _, _}} ->
        failure("Could not resume - schedule is not currently snoozed")
        {:noreply, socket}
    end
  end
end
