defmodule PlausibleWeb.Live.Teams do
  @moduledoc """
  LiveView for Team setup
  """

  use PlausibleWeb, :live_view

  alias Plausible.Teams
  alias PlausibleWeb.Live.Components.ComboBox
  alias Plausible.Teams.Invitations.Candidates
  alias Plausible.Auth.User

  def mount(_params, _session, socket) do
    my_team = socket.assigns.my_team
    team_name_changeset = Teams.Team.name_changeset(my_team)
    socket = assign(socket, team_name_changeset: team_name_changeset)
    {:ok, socket}
  end

  def handle_params(_params, _uri, socket) do
    {:noreply, socket}
  end

  def render(assigns) do
    ~H"""
    <.focus_box>
      <:title>Create a new team</:title>
      <:subtitle>
        Add members and assign roles to manage different sites access efficiently
      </:subtitle>

      <.form :let={f} for={@team_name_changeset} method="post">
        <.input type="text" field={f[:name]} label="Name" width="w-1/2" />
      </.form>

      <div class="mt-4">
        <.label>
          Add members
        </.label>

        <.live_component
          id="id"
          submit_name="some"
          class="py-2"
          module={ComboBox}
          suggest_fun={
            fn input, _options ->
              @my_team
              |> Candidates.search_site_guests(input)
              |> Enum.map(fn user -> {user.id, "#{user.name} <#{user.email}>"} end)
            end
          }
        />
      </div>

      <.member user={@current_user} role={:owner} you?={true} />
      <.member user={%User{email: "test@example.com", name: "Joe Doe"}} role={:other} />
      <.member user={%User{email: "test2@example.com", name: "Jane Doe"}} role={:other} />
      <.member user={%User{email: "test3@example.com", name: "Flash Doe"}} role={:other} />
    </.focus_box>
    """
  end

  attr :user, User, required: true
  attr :you?, :boolean, default: false
  attr :role, :atom, default: nil

  def member(assigns) do
    ~H"""
    <div class="mt-2">
      <div class="flex items-center gap-x-5">
        <img src={User.profile_img_url(@user)} class="w-7 rounded-full" />
        <span class="text-sm">
          <%= @user.name %>

          <span :if={@you?} class="ml-1 bg-gray-100 text-gray-500 text-xs p-1 rounded">
            You
          </span>

          <br /><span class="text-gray-500 text-xs"><%= @user.email %></span>
        </span>
        <div :if={@role == :owner} class="flex-1 text-right">

          <.dropdown class="relative">
          <:button class="bg-transparent text-gray-800 dark:text-gray-100 hover:bg-gray-50 dark:hover:bg-gray-700 focus-visible:outline-gray-100 whitespace-nowrap truncate inline-flex items-center gap-x-2 font-medium rounded-md px-3.5 py-2.5 text-sm focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 disabled:bg-gray-400 dark:disabled:text-white dark:disabled:text-gray-400 dark:disabled:bg-gray-700">
          <%= @role %>
          <Heroicons.chevron_down mini class="size-4 mt-0.5" />
          </:button>
          <:menu class="max-w-60">
          <.dropdown_item disabled={true}>
          <div>Owner</div>
          <div class="text-gray-500 dark:text-gray-400 text-xs/5">
          Site owner cannot be assigned to any other role
          </div>
          </.dropdown_item>
          </:menu>
          </.dropdown>

        </div>
        <div :if={@role != :owner} class="flex-1 text-right">
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
end
