defmodule PlausibleWeb.CustomerSupport.Team.Components.Overview do
  @moduledoc """
  Team overview component - handles team basic info, trial dates, notes
  """
  use PlausibleWeb, :live_component
  import PlausibleWeb.CustomerSupport.Live

  def update(%{team: team}, socket) do
    changeset = Plausible.Teams.Team.crm_changeset(team, %{})
    form = to_form(changeset)

    {:ok, assign(socket, team: team, form: form)}
  end

  def render(assigns) do
    ~H"""
    <div class="mt-8">
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

  def handle_event("save-team", %{"team" => params}, socket) do
    changeset = Plausible.Teams.Team.crm_changeset(socket.assigns.team, params)

    case Plausible.Repo.update(changeset) do
      {:ok, team} ->
        success("Team saved")
        {:noreply, assign(socket, team: team, form: to_form(changeset))}

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
end
