defmodule PlausibleWeb.CustomerSupport.Team.Components.Members do
  @moduledoc """
  Team members component - handles team member management
  """
  use PlausibleWeb, :live_component
  alias Plausible.Teams.Management.Layout
  import PlausibleWeb.Components.Generic

  def update(%{team: team}, socket) do
    {:ok, refresh_members(socket, team)}
  end

  def render(assigns) do
    ~H"""
    <div class="mt-2">
      <.table rows={Layout.sorted_for_display(@team_layout)}>
        <:thead>
          <.th>User</.th>
          <.th>Sessions</.th>
          <.th>Type</.th>
          <.th>Role</.th>
        </:thead>
        <:tbody :let={{_, member}}>
          <.td truncate>
            <div :if={member.id != 0}>
              <.styled_link
                patch={"/cs/users/user/#{member.id}"}
                class="cursor-pointer flex block items-center"
              >
                <img
                  src={Plausible.Auth.User.profile_img_url(%Plausible.Auth.User{email: member.email})}
                  class="mr-4 w-6 rounded-full bg-gray-300"
                />
                {member.name} &lt;{member.email}&gt;
              </.styled_link>
            </div>
            <div :if={member.id == 0} class="flex items-center">
              <img
                src={Plausible.Auth.User.profile_img_url(%Plausible.Auth.User{email: member.email})}
                class="mr-4 w-6 rounded-full bg-gray-300"
              />
              {member.name} &lt;{member.email}&gt;
            </div>
          </.td>
          <.td>
            {if member.type == :membership, do: @session_counts[member.meta.user.id] || 0, else: 0}
          </.td>
          <.td>
            <div class="flex items-center gap-x-1">
              <span :if={member.type == :membership && member.meta.user.type == :sso}>SSO </span>{member.type}

              <.delete_button
                :if={member.type == :membership && member.meta.user.type == :sso}
                id={"deprovision-sso-user-#{member.id}"}
                phx-click="deprovision-sso-user"
                phx-value-identifier={member.id}
                phx-target={@myself}
                class="text-sm"
                icon={:user_minus}
                data-confirm="Are you sure you want to deprovision SSO user and convert them to a standard user? This will sign them out and force to use regular e-mail/password combination to log in again."
              />
            </div>
          </.td>
          <.td>
            {member.role}
          </.td>
        </:tbody>
      </.table>
    </div>
    """
  end

  def handle_event("deprovision-sso-user", %{"identifier" => user_id}, socket) do
    [id: String.to_integer(user_id)]
    |> Plausible.Auth.find_user_by()
    |> Plausible.Auth.SSO.deprovision_user!()

    send(self(), {:success, "SSO user deprovisioned"})
    {:noreply, refresh_members(socket, socket.assigns.team)}
  end

  defp refresh_members(socket, team) do
    team_layout = Layout.init(team)

    session_counts =
      team_layout
      |> Enum.map(fn {_, entry} -> if entry.type == :membership, do: entry.meta.user end)
      |> Enum.reject(&is_nil/1)
      |> Plausible.Auth.UserSessions.count_for_users()
      |> Enum.into(%{})

    assign(socket, team: team, team_layout: team_layout, session_counts: session_counts)
  end
end
