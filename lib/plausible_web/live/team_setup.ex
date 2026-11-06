defmodule PlausibleWeb.Live.TeamSetup do
  @moduledoc """
  LiveView for Team setup
  """

  use PlausibleWeb, :live_view

  import PlausibleWeb.Live.Components.Team, only: [role_select_input: 1]

  alias Plausible.Teams
  alias PlausibleWeb.{Flows, Layouts}

  def mount(params, _session, socket) do
    user = socket.assigns.current_user
    onboarding? = params["flow"] == Flows.register()
    domain = accessible_domain(user, params["domain"])

    if onboarding? and Teams.setup?(socket.assigns.current_team) do
      {:ok, redirect(socket, to: onboarding_next_step_path(domain))}
    else
      suggested_name = Teams.Team.suggested_name_from_domain(domain, user.name)
      name_changeset = Teams.Team.name_changeset(%Teams.Team{}, %{name: suggested_name})
      move? = match?(%{current_team: %{id: id}, my_team: %{id: id}}, socket.assigns)
      show_move? = move? and not onboarding?

      owned_sites =
        if show_move?, do: Teams.owned_sites(socket.assigns.current_team), else: []

      socket =
        socket
        |> assign(
          onboarding?: onboarding?,
          domain: domain,
          team_name_form: to_form(name_changeset),
          show_move_from_current_team?: show_move?,
          owned_sites: owned_sites
        )
        |> assign_move_from_current_team(move?)

      {:ok, socket}
    end
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
      heading="Create a team"
      subtitle="Name your team and optionally invite members by email."
    />
    <div class="w-full max-w-md mx-auto mt-10 pb-16 px-4 dark:text-gray-300">
      <.flash_messages flash={@flash} />

      <.form
        :let={f}
        for={@team_name_form}
        id="create-team-form"
        phx-submit="create-team"
      >
        <.move_from_current_team_picker
          :if={@show_move_from_current_team?}
          move?={@move_from_current_team?}
          owned_sites={@owned_sites}
        />

        <div class="relative">
          <PlausibleWeb.Components.Billing.feature_gate
            current_user={@current_user}
            current_team={@current_team}
            locked?={@locked?}
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
                  :for={n <- 1..max_rows(@team_member_limit)//1}
                  row={%{id: n, email: "", role: :viewer}}
                  hidden?={n > 1}
                />
              </div>

              <.add_row_button data-add-row class="mt-3" />

              <div data-add-row-disabled class="mt-3 hidden">
                <.tooltip hover_only?>
                  <:tooltip_content>{add_row_tooltip(@team_member_limit)}</:tooltip_content>
                  <.add_row_button disabled />
                </.tooltip>
              </div>
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
          </PlausibleWeb.Components.Billing.feature_gate>
        </div>
      </.form>
    </div>
    """
  end

  attr(:move?, :boolean, required: true)
  attr(:owned_sites, :list, required: true)

  defp move_from_current_team_picker(assigns) do
    ~H"""
    <fieldset id="move-from-current-team-picker" class="mb-6 flex flex-col gap-y-3">
      <.label>What should happen to your personal sites?</.label>

      <.input
        type="radio"
        id="move-from-current-team-true"
        name="move_from_current_team"
        value="true"
        checked={@move?}
        wrapper_class={option_card_class(@move?)}
        phx-click="select-move-from-current-team"
        label="Move into this team"
        help_text="Sites keep their stats, guests keep their access, and your subscription moves along."
      >
        <:help_content>
          <span class="mt-2 flex flex-wrap gap-2">
            <.pill :for={site <- @owned_sites} class="gap-x-1.5">
              <PlausibleWeb.Live.Sites.favicon domain={site.domain} />
              {site.domain}
            </.pill>
          </span>
        </:help_content>
      </.input>

      <.input
        type="radio"
        id="move-from-current-team-false"
        name="move_from_current_team"
        value="false"
        checked={not @move?}
        wrapper_class={option_card_class(not @move?)}
        phx-click="select-move-from-current-team"
        label="Start with an empty team"
        help_text="Your personal sites stay where they are. You can move individual sites later in their site settings."
      />
    </fieldset>
    """
  end

  defp option_card_class(selected?) do
    [
      "p-4 rounded-lg border",
      if(selected?,
        do: "border-indigo-600 ring-1 ring-indigo-600 bg-indigo-50/50 dark:bg-indigo-900/20",
        else: "border-gray-300 dark:border-gray-700"
      )
    ]
  end

  attr(:class, :string, default: nil)
  attr(:rest, :global, include: ~w(disabled))

  defp add_row_button(assigns) do
    ~H"""
    <button
      type="button"
      class={[
        @class,
        "inline-flex items-center gap-x-1 text-sm font-medium text-indigo-600 hover:text-indigo-700 dark:text-indigo-400 dark:hover:text-indigo-300 disabled:pointer-events-none disabled:text-gray-400 dark:disabled:text-gray-500"
      ]}
      {@rest}
    >
      <Heroicons.plus class="size-4" /> Add another
    </button>
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

  def handle_event("select-move-from-current-team", %{"value" => value}, socket) do
    {:noreply, assign_move_from_current_team(socket, value == "true")}
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
      if socket.assigns.move_from_current_team? do
        Teams.setup(socket.assigns.current_team, name, entries, user)
      else
        Teams.create(user, name, entries)
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
        {:noreply, put_live_flash(socket, :error, member_limit_message(limit))}
    end
  end

  defp assign_move_from_current_team(socket, move?) do
    team = if move?, do: socket.assigns.current_team

    assign(socket,
      move_from_current_team?: move?,
      locked?: move? and Teams.Billing.solo?(team),
      team_member_limit: Teams.Billing.team_member_limit(team)
    )
  end

  defp accessible_domain(user, domain) when is_binary(domain) do
    case Plausible.Sites.get_for_user(user, domain) do
      %Plausible.Site{} = site -> site.domain
      nil -> nil
    end
  end

  defp accessible_domain(_user, _domain), do: nil

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
  defp max_rows(:unlimited), do: @max_rows_when_unlimited
  defp max_rows(limit), do: limit

  defp add_row_tooltip(:unlimited), do: "You can invite more members later in team settings."
  defp add_row_tooltip(limit), do: member_limit_message(limit)

  defp member_limit_message(limit) do
    "Your account is limited to #{limit} team members. You can upgrade your plan to increase this limit."
  end
end
