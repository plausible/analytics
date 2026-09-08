defmodule PlausibleWeb.Live.TeamSetup do
  @moduledoc """
  LiveView for Team setup
  """

  use PlausibleWeb, :live_view

  alias Plausible.Repo
  alias Plausible.Teams
  alias Plausible.Teams.Management.Layout
  alias PlausibleWeb.Router.Helpers, as: Routes

  def mount(_params, _session, socket) do
    socket =
      case socket.assigns.current_team do
        %Teams.Team{setup_complete: true} ->
          socket
          |> put_flash(:success, "Your team is now created")
          |> redirect(to: Routes.settings_path(socket, :team_general))

        %Teams.Team{} = team ->
          setup(socket, team)

        _ ->
          socket
          |> put_flash(:error, "You cannot create any team just yet")
          |> redirect(to: Routes.site_path(socket, :index))
      end

    {:ok, socket}
  end

  defp setup(socket, team) do
    suggested_name = Teams.Team.suggested_name(socket.assigns.current_user.name)

    team =
      team
      |> Teams.Team.name_changeset(%{name: suggested_name})
      |> Repo.update!()

    {:ok, my_role} = Teams.Memberships.team_role(team, socket.assigns.current_user)

    assign(socket,
      current_team: team,
      team_name_form: to_form(Teams.Team.name_changeset(team, %{})),
      locked?: Plausible.Teams.Billing.solo?(team),
      my_role: my_role,
      rows: [%{id: 1, email: "", role: :viewer}],
      next_row_id: 2
    )
  end

  def render(assigns) do
    ~H"""
    <.focus_box padding?={false}>
      <:title>
        <div class="pt-8 px-8 flex justify-between">
          <div>Create a new team</div>
          <div class="ml-auto">
            <.docs_info slug="users-roles" />
          </div>
        </div>
      </:title>
      <:subtitle>
        <p class="px-8">
          Name your team and optionally invite members by email. When ready, click "Create team"
        </p>
      </:subtitle>

      <div class="relative -mt-8 pt-4 pb-8 px-8">
        <PlausibleWeb.Components.Billing.feature_gate
          current_user={@current_user}
          current_team={@current_team}
          locked?={@locked?}
        >
          <.flash_messages flash={@flash} />

          <.form
            :let={f}
            for={@team_name_form}
            method="post"
            phx-change="update-team"
            phx-submit="update-team"
            phx-blur="update-team"
            id="update-team-form"
            class="mt-4 mb-8"
          >
            <.input
              type="text"
              placeholder={"#{@current_user.name}'s team"}
              autofocus={not @locked?}
              field={f[:name]}
              label="Name"
              width="w-full"
              phx-debounce="500"
            />
          </.form>

          <div class="flex items-center justify-between mb-2">
            <.label class="mb-0">
              Team members
            </.label>

            <button
              type="button"
              aria-label="Add member"
              phx-click="add-row"
              class="text-gray-400 hover:text-gray-600 dark:hover:text-gray-300"
            >
              <Heroicons.plus class="size-4" />
            </button>
          </div>

          <.form id="member-rows-form" for={} phx-change="update-rows" phx-submit="create-team">
            <div id="member-rows">
              <div
                :for={row <- @rows}
                id={"member-row-#{row.id}"}
                class="flex items-center gap-x-3 mt-3"
              >
                <div class="flex-1">
                  <.input
                    type="email"
                    name={"rows[#{row.id}][email]"}
                    value={row.email}
                    placeholder="Enter e-mail"
                    phx-debounce={200}
                    mt?={false}
                  />
                </div>

                <PlausibleWeb.Live.Components.Team.role_picker
                  id={"role-picker-#{row.id}"}
                  role={row.role}
                  my_role={@my_role}
                  phx-click="select-row-role"
                  phx-value-row-id={row.id}
                />

                <button
                  type="button"
                  aria-label="Remove row"
                  phx-click="remove-row"
                  phx-value-row-id={row.id}
                  class="text-gray-400 hover:text-gray-600 dark:hover:text-gray-300"
                >
                  <Heroicons.minus class="size-4" />
                </button>
              </div>
            </div>

            <.button
              id="create-team-submit"
              type="submit"
              disabled={not @team_name_form.source.valid?}
              class="mt-8 w-full"
            >
              Create team
            </.button>
          </.form>
        </PlausibleWeb.Components.Billing.feature_gate>
      </div>
    </.focus_box>
    """
  end

  def handle_event("update-team", %{"team" => %{"name" => name}}, socket) do
    changeset = Teams.Team.name_changeset(socket.assigns.current_team, %{name: name})

    socket =
      case Repo.update(changeset) do
        {:ok, team} ->
          assign(socket, team_name_form: to_form(changeset), current_team: team)

        {:error, changeset} ->
          assign(socket, team_name_form: to_form(changeset))
      end

    {:noreply, socket}
  end

  def handle_event("add-row", _params, socket) do
    id = socket.assigns.next_row_id
    rows = socket.assigns.rows ++ [%{id: id, email: "", role: :viewer}]
    {:noreply, assign(socket, rows: rows, next_row_id: id + 1)}
  end

  def handle_event("remove-row", %{"row-id" => row_id}, socket) do
    row_id = String.to_integer(row_id)
    rows = Enum.reject(socket.assigns.rows, &(&1.id == row_id))
    {:noreply, assign(socket, rows: rows)}
  end

  def handle_event("select-row-role", %{"row-id" => row_id, "role" => role}, socket) do
    row_id = String.to_integer(row_id)
    role = PlausibleWeb.Live.Components.Team.role_to_atom(role)

    rows =
      Enum.map(socket.assigns.rows, fn
        %{id: ^row_id} = row -> %{row | role: role}
        row -> row
      end)

    {:noreply, assign(socket, rows: rows)}
  end

  def handle_event("update-rows", params, socket) do
    rows_params = Map.get(params, "rows", %{})

    rows =
      Enum.map(socket.assigns.rows, fn row ->
        case rows_params[to_string(row.id)] do
          %{"email" => email} -> %{row | email: String.trim(email)}
          _ -> row
        end
      end)

    {:noreply, assign(socket, rows: rows)}
  end

  def handle_event("create-team", params, socket) do
    if socket.assigns.team_name_form.source.valid? do
      create_team(socket, Map.get(params, "rows", %{}))
    else
      {:noreply, put_live_flash(socket, :error, "Please fix the team name first")}
    end
  end

  defp create_team(socket, rows_params) do
    entries =
      socket.assigns.rows
      |> Enum.map(fn row ->
        email =
          rows_params
          |> Map.get(to_string(row.id), %{})
          |> Map.get("email", "")
          |> String.trim()

        %{row | email: email}
      end)
      |> Enum.filter(&(&1.email != ""))

    emails = Enum.map(entries, & &1.email)

    cond do
      Enum.any?(emails, &(not valid_email?(&1))) ->
        {:noreply, put_live_flash(socket, :error, "Make sure all e-mails are valid")}

      Enum.uniq(emails) != emails ->
        {:noreply, put_live_flash(socket, :error, "Make sure e-mails are unique")}

      true ->
        layout =
          Enum.reduce(entries, %{}, fn %{email: email, role: role}, layout ->
            Layout.schedule_send(layout, email, role)
          end)

        persist_layout(socket, layout)
    end
  end

  defp persist_layout(socket, layout) do
    case Layout.persist(layout, %{
           current_user: socket.assigns.current_user,
           current_team: socket.assigns.current_team
         }) do
      {:ok, _} ->
        {:noreply,
         socket
         |> put_flash(:success, "Your team is now created")
         |> redirect(
           to:
             Routes.settings_path(socket, :team_general,
               __team: socket.assigns.current_team.identifier
             )
         )}

      {:error, :permission_denied} ->
        {:noreply, put_live_flash(socket, :error, "Permission denied")}

      {:error, :only_one_owner} ->
        {:noreply, put_live_flash(socket, :error, "The team has to have at least one owner")}

      {:error, :disabled_2fa} ->
        {:noreply,
         put_live_flash(socket, :error, "User must have 2FA enabled to become an owner")}

      {:error, {:over_limit, limit}} ->
        {:noreply,
         put_live_flash(
           socket,
           :error,
           "Your account is limited to #{limit} team members. You can upgrade your plan to increase this limit"
         )}
    end
  end

  defp valid_email?(email) do
    String.contains?(email, "@") and String.contains?(email, ".")
  end
end
