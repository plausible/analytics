defmodule PlausibleWeb.Live.Teams do
  @moduledoc """
  LiveView for Team setup
  """

  use PlausibleWeb, :live_view

  alias Plausible.Repo
  alias Plausible.Teams
  alias PlausibleWeb.Live.Components.ComboBox
  alias Plausible.Teams.Invitations.Candidates
  alias Plausible.Auth.User

  def mount(_params, _session, socket) do
    my_team = socket.assigns.my_team

    all_candidates =
      my_team
      |> Candidates.search_site_guests("")
      |> Enum.map(fn user ->
        {user.email, "#{user.name} <#{user.email}>"}
      end)

    candidates_selected = %{}
    team_name_changeset = Teams.Team.name_changeset(my_team)

    socket =
      assign(socket,
        all_candidates: all_candidates,
        team_name_changeset: team_name_changeset,
        candidates_selected: candidates_selected
      )

    {:ok, socket}
  end

  def handle_params(_params, _uri, socket) do
    {:noreply, socket}
  end

  def render(assigns) do
    ~H"""
    <.flash_messages flash={@flash} />
    <.focus_box>
      <:title>Create a new team</:title>
      <:subtitle>
        Add members and assign roles to manage different sites access efficiently
      </:subtitle>

      <.form :let={f} for={@team_name_changeset} method="post">
        <.input
          type="text"
          field={f[:name]}
          label="Name"
          width="w-1/2"
          phx-change="update-team"
          phx-debounce="500"
        />
      </.form>

      <div class="mt-4">
        <.label>
          Add members
        </.label>

        <.form for={}>
          <.live_component
            id="team-member-candidates"
            submit_name="some"
            class="py-2"
            module={ComboBox}
            clear_on_select
            creatable
            creatable_prompt="Send invitation to email:"
            placeholder="Select existing member or type email address to invite"
            options={
              reject_already_selected("team-member-candidates", @all_candidates, @candidates_selected)
            }
            on_selection_made={
              fn email, _name, _by_id ->
                send(self(), {:candidate_selected, %{email: email, role: :viewer}})
                {:ok, email, ""}
              end
            }
            suggest_fun={
              fn input, _options ->
                exclude_emails =
                  Enum.map(@candidates_selected, fn {{email, _}, _} -> email end)

                @my_team
                |> Candidates.search_site_guests(input, exclude: exclude_emails)
                |> Enum.map(fn user -> {user.email, "#{user.name} <#{user.email}>"} end)
              end
            }
            x-on-selection-change="document.getElementById('team-member-candidates').value = ''"
          />
        </.form>
      </div>

      <.member user={@current_user} role={:owner} you?={true} />

      <%= for {{email, name}, role} <- @candidates_selected do %>
        <.member user={%User{email: email, name: name}} role={role} />
      <% end %>
    </.focus_box>
    """
  end

  attr :user, User, required: true
  attr :you?, :boolean, default: false
  attr :role, :atom, default: nil

  def member(assigns) do
    ~H"""
    <div class="mt-4">
      <div class="flex items-center gap-x-5">
        <img src={User.profile_img_url(@user)} class="w-7 rounded-full" />
        <span class="text-sm">
          <%= @user.name %>

          <span :if={@you?} class="ml-1 bg-gray-100 text-gray-500 text-xs p-1 rounded">
            You
          </span>

          <br /><span class="text-gray-500 text-xs"><%= @user.email %></span>
        </span>
        <div class="flex-1 text-right">
          <.dropdown class="relative">
            <:button class="bg-transparent text-gray-800 dark:text-gray-100 hover:bg-gray-50 dark:hover:bg-gray-700 focus-visible:outline-gray-100 whitespace-nowrap truncate inline-flex items-center gap-x-2 font-medium rounded-md px-3.5 py-2.5 text-sm focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 disabled:bg-gray-400 dark:disabled:text-white dark:disabled:text-gray-400 dark:disabled:bg-gray-700">
              <%= @role %>
              <Heroicons.chevron_down mini class="size-4 mt-0.5" />
            </:button>
            <:menu class="max-w-60">
              <.dropdown_item href={} method="put" disabled={}>
                <div>Admin</div>
                <div class="text-gray-500 dark:text-gray-400 text-xs/5">
                  View stats and edit site settings
                </div>
              </.dropdown_item>
            </:menu>
          </.dropdown>
        </div>
      </div>
    </div>
    """
  end

  def handle_info(
        {:candidate_selected, %{email: email, role: role}},
        %{assigns: %{my_team: team, candidates_selected: candidates}} = socket
      ) do
    socket =
      case Candidates.get_site_guest(team, email) do
        %User{} = user ->
          assign(
            socket,
            :candidates_selected,
            Map.put(candidates, {user.email, user.name}, role)
          )

        nil ->
          if valid_email?(email) do
            assign(
              socket,
              :candidates_selected,
              Map.put(candidates, {email, "Invited User"}, role)
            )
          else
            put_live_flash(
              socket,
              :error,
              "Sorry, e-mail '#{email}' is invalid. Please type the address again."
            )
          end
      end

    {:noreply, socket}
  end

  def handle_event("update-team", %{"team" => params}, socket) do
    team_name_changeset =
      socket.assigns.my_team
      |> Teams.Team.name_changeset(params)

    my_team = Repo.update!(team_name_changeset)

    {:noreply,
     assign(socket,
       team_name_changeset: team_name_changeset,
       my_team: my_team
     )}
  end

  defp valid_email?(email) do
    String.contains?(email, "@") and String.contains?(email, ".")
  end

  defp reject_already_selected(combo_box, candidates, candidates_selected) do
    result =
      candidates
      |> Enum.reject(fn {email, _} ->
        Enum.find(candidates_selected, fn
          {{^email, _}, _} -> true
          _ -> false
        end)
      end)

    send_update(PlausibleWeb.Live.Components.ComboBox, id: combo_box, suggestions: result)
    result
  end
end
