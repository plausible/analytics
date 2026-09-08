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
    name_changeset = Teams.Team.name_changeset(team, %{name: suggested_name})

    assign(socket,
      current_team: team,
      team_name_form: to_form(name_changeset),
      locked?: Plausible.Teams.Billing.solo?(team)
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

          <.form :let={f} for={@team_name_form} id="create-team-form" phx-submit="create-team">
            <.input
              type="text"
              placeholder={"#{@current_user.name}'s team"}
              autofocus={not @locked?}
              field={f[:name]}
              label="Name"
              width="w-full"
            />

            <div id="member-rows-container" phx-hook="MemberRows">
              <div class="flex items-center justify-between mb-2 mt-4">
                <.label>
                  Team members
                </.label>

                <button
                  type="button"
                  aria-label="Add member"
                  data-add-row
                  class="text-gray-400 hover:text-gray-600 dark:hover:text-gray-300"
                >
                  <Heroicons.plus class="size-4" />
                </button>
              </div>

              <div id="member-rows" data-row-list>
                <.member_row row={%{id: "1", email: "", role: :viewer}} />
              </div>

              <template data-row-template>
                <.member_row row={%{id: "__ROW_ID__", email: "", role: :viewer}} />
              </template>
            </div>

            <.button id="create-team-submit" type="submit" class="mt-8 w-full">
              Create team
            </.button>
          </.form>
        </PlausibleWeb.Components.Billing.feature_gate>
      </div>
    </.focus_box>
    """
  end

  attr(:row, :map, required: true)

  defp member_row(assigns) do
    ~H"""
    <div id={"member-row-#{@row.id}"} data-row class="flex items-center gap-x-3 mt-3">
      <div class="flex-1">
        <.input
          type="email"
          name={"rows[#{@row.id}][email]"}
          value={@row.email}
          placeholder="Enter e-mail"
          mt?={false}
        />
      </div>

      <details
        name="role-picker-group"
        data-role-picker
        class="relative inline-block text-left"
      >
        <summary
          id={"role-picker-#{@row.id}-trigger"}
          role="button"
          aria-haspopup="listbox"
          aria-expanded="false"
          class="role w-[100px] list-none [&::-webkit-details-marker]:hidden cursor-pointer inline-flex items-center justify-between font-medium rounded-md px-3 py-2 text-sm border border-gray-300 dark:border-gray-750 text-gray-800 dark:text-gray-100 dark:bg-gray-750 dark:hover:bg-gray-700 whitespace-nowrap truncate shadow-xs hover:shadow-sm transition-all duration-150"
        >
          <span data-role-label>{@row.role |> Atom.to_string() |> String.capitalize()}</span>
          <Heroicons.chevron_down mini class="size-4 mt-0.5" />
        </summary>

        <div
          role="listbox"
          aria-labelledby={"role-picker-#{@row.id}-trigger"}
          class="absolute right-0 z-50 mt-2 w-max p-1.5 rounded-md shadow-lg overflow-hidden bg-white dark:bg-gray-800 ring-1 ring-black/5"
        >
          <button
            :for={{role, description} <- PlausibleWeb.Live.Components.Team.role_descriptions()}
            type="button"
            role="option"
            aria-selected={to_string(role == @row.role)}
            tabindex="-1"
            data-role-item={role}
            class="block w-full max-w-60 text-left rounded-md text-sm/6 text-gray-900 dark:text-gray-100 hover:bg-gray-100 dark:hover:bg-gray-700/80 px-3 py-1.5"
          >
            <div>{role |> Atom.to_string() |> String.capitalize()}</div>
            <div class="text-gray-500 dark:text-gray-400 text-xs/5">{description}</div>
          </button>
        </div>
      </details>

      <input type="hidden" name={"rows[#{@row.id}][role]"} value={@row.role} data-role-value />

      <button
        type="button"
        aria-label="Remove row"
        data-remove-row
        class="text-gray-400 hover:text-gray-600 dark:hover:text-gray-300"
      >
        <Heroicons.minus class="size-4" />
      </button>
    </div>
    """
  end

  def handle_event("create-team", %{"team" => %{"name" => name}} = params, socket) do
    changeset = Teams.Team.name_changeset(socket.assigns.current_team, %{name: name})

    case Repo.update(changeset) do
      {:ok, team} ->
        create_team(
          assign(socket, current_team: team),
          Map.get(params, "rows", %{})
        )

      {:error, changeset} ->
        {:noreply, assign(socket, team_name_form: to_form(changeset))}
    end
  end

  defp create_team(socket, rows_params) do
    entries =
      rows_params
      |> Map.values()
      |> Enum.map(fn row_params ->
        email = row_params |> Map.get("email", "") |> String.trim()

        role =
          PlausibleWeb.Live.Components.Team.role_to_atom(Map.get(row_params, "role", "viewer"))

        %{email: email, role: role}
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
