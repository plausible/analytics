defmodule PlausibleWeb.Live.TeamSetup do
  @moduledoc """
  LiveView for Team setup
  """

  use PlausibleWeb, :live_view

  import PlausibleWeb.Live.Components.Team, only: [role_select_input: 1]

  alias Plausible.Teams
  alias PlausibleWeb.{Flows, Layouts}

  def mount(params, _session, socket) do
    team = socket.assigns.current_team
    onboarding? = params["flow"] == Flows.register()
    domain = params["domain"]

    socket =
      cond do
        Teams.setup?(team) and onboarding? ->
          redirect(socket, to: onboarding_next_step_path(domain))

        Teams.setup?(team) ->
          socket
          |> put_flash(:success, "Your team has already been created")
          |> redirect(to: ~p"/settings/team/general")

        true ->
          suggested_name =
            Teams.Team.suggested_name_from_domain(domain, socket.assigns.current_user.name)

          name_changeset =
            Teams.Team.name_changeset(team || %Teams.Team{}, %{name: suggested_name})

          assign(socket,
            team: team,
            onboarding?: onboarding?,
            domain: domain,
            team_name_form: to_form(name_changeset),
            locked?: not is_nil(team) and Plausible.Teams.Billing.solo?(team),
            max_new_members: max_new_members(team)
          )
      end

    {:ok, socket}
  end

  def render(assigns) do
    ~H"""
    <.onboarding_or_app_layout {assigns}>
      <.team_setup_form {assigns} />
    </.onboarding_or_app_layout>
    """
  end

  defp onboarding_or_app_layout(assigns) do
    if assigns.onboarding? do
      ~H"""
      <Layouts.onboarding current_step={Flows.team_setup_step()} current_user={@current_user}>
        {render_slot(@inner_block)}
      </Layouts.onboarding>
      """
    else
      ~H"""
      <Layouts.app
        footer?={false}
        global_notices?={false}
        current_user={@current_user}
        current_team={@current_team}
        current_team_role={@current_team_role}
        teams={@teams}
        my_team={@my_team}
      >
        {render_slot(@inner_block)}
      </Layouts.app>
      """
    end
  end

  defp team_setup_form(assigns) do
    ~H"""
    <.onboarding_page_heading
      heading="Create a new team"
      subtitle="Name your team and optionally invite members by email."
    />
    <div class="w-full max-w-md mx-auto mt-10 pb-16 px-4 dark:text-gray-300">
      <div class="relative">
        <PlausibleWeb.Components.Billing.feature_gate
          current_user={@current_user}
          current_team={@team}
          locked?={@locked?}
        >
          <.flash_messages flash={@flash} />

          <.form
            :let={f}
            for={@team_name_form}
            id="create-team-form"
            phx-submit="create-team"
          >
            <.input
              type="text"
              placeholder={"#{@current_user.name}'s team"}
              autofocus={not @locked?}
              field={f[:name]}
              label="Name"
              width="w-full"
              required
            />

            <div id="member-rows-container" phx-hook="MemberRows">
              <.label class="mb-2 mt-4">
                Team members
              </.label>

              <div id="member-rows" data-row-list>
                <.member_row
                  :for={n <- 1..@max_new_members//1}
                  row={%{id: n, email: "", role: :viewer}}
                  hidden?={n > 1}
                />
              </div>

              <button
                type="button"
                data-add-row
                class="mt-3 inline-flex items-center gap-x-1 text-sm font-medium text-indigo-600 hover:text-indigo-700 dark:text-indigo-400 dark:hover:text-indigo-300"
              >
                <Heroicons.plus class="size-4" /> Add another
              </button>
            </div>

            <div class="mt-8 flex justify-end items-center gap-x-2">
              <%= if @onboarding? do %>
                <.button_link
                  id="create-team-skip"
                  theme="ghost"
                  href={onboarding_next_step_path(@domain)}
                >
                  Skip
                </.button_link>
              <% else %>
                <.button_link id="create-team-cancel" theme="ghost" href={~p"/sites"}>
                  Cancel
                </.button_link>
              <% end %>
              <.button id="create-team-submit" type="submit">
                Create team
              </.button>
            </div>
          </.form>
        </PlausibleWeb.Components.Billing.feature_gate>
      </div>
    </div>
    """
  end

  attr(:row, :map, required: true)
  attr(:hidden?, :boolean, default: false)

  defp member_row(assigns) do
    ~H"""
    <div
      id={"member-row-#{@row.id}"}
      data-row
      class={["items-center gap-x-3 mt-3", if(@hidden?, do: "hidden", else: "flex")]}
    >
      <div class="flex-1">
        <.input
          type="email"
          name={"rows[#{@row.id}][email]"}
          value={@row.email}
          placeholder="Enter e-mail"
        />
      </div>

      <.role_select_input
        id={"role-select-#{@row.id}"}
        name={"rows[#{@row.id}][role]"}
        role={@row.role}
        my_role={:owner}
      />

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
    create_team(socket, name, Map.get(params, "rows", %{}))
  end

  defp create_team(socket, name, rows_params) do
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

    setup_team(socket, name, entries)
  end

  defp setup_team(socket, name, entries) do
    user = socket.assigns.current_user

    result =
      case socket.assigns.team do
        nil -> Teams.create(user, name, entries)
        team -> Teams.setup(team, name, entries, user)
      end

    case result do
      {:ok, team} ->
        redirect_path =
          success_redirect_path(socket.assigns.onboarding?, socket.assigns.domain,
            __team: team.identifier
          )

        {:noreply,
         socket
         |> put_flash(:success, "Your team is now created")
         |> redirect(to: redirect_path)}

      {:error, %Ecto.Changeset{data: %Teams.Team{}} = changeset} ->
        {:noreply, assign(socket, team_name_form: to_form(changeset))}

      {:error, :invalid_email} ->
        {:noreply, put_live_flash(socket, :error, "Make sure all e-mails are valid")}

      {:error, :duplicate_emails} ->
        {:noreply, put_live_flash(socket, :error, "Make sure e-mails are unique")}

      {:error, reason} when reason in [:already_a_guest, :invited_as_guest] ->
        {:noreply,
         put_live_flash(
           socket,
           :error,
           "Some of these e-mails belong to site guests who cannot be invited at this stage. Please invite them later in team settings"
         )}

      {:error, :already_a_member} ->
        {:noreply, put_live_flash(socket, :error, "You cannot invite yourself")}

      {:error, {:over_limit, limit}} ->
        {:noreply,
         put_live_flash(
           socket,
           :error,
           "Your account is limited to #{limit} team members. You can upgrade your plan to increase this limit"
         )}
    end
  end

  defp success_redirect_path(onboarding?, domain, params) do
    if onboarding? do
      onboarding_next_step_path(domain, params)
    else
      ~p"/settings/team/general?#{params}"
    end
  end

  defp onboarding_next_step_path(domain, params \\ []) do
    if is_nil(domain) do
      ~p"/sites?#{params}"
    else
      ~p"/#{domain}/installation?#{[flow: Flows.register()] ++ params}"
    end
  end

  @max_rows_when_unlimited 20

  # The upper bound for how many email+role input rows the UI
  # should render at most, in order to prevent the user getting a
  # "team member limit exceeded" error upon submit without any prior
  # indication about it.
  defp max_new_members(team) do
    case Teams.Billing.team_member_limit(team) do
      :unlimited -> @max_rows_when_unlimited
      limit -> limit
    end
  end
end
