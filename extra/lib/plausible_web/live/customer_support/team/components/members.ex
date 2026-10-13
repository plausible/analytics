defmodule PlausibleWeb.CustomerSupport.Team.Components.Members do
  @moduledoc """
  Team members component - handles team member management
  """
  use PlausibleWeb, :live_component
  import PlausibleWeb.CustomerSupport.Live
  import PlausibleWeb.CustomerSupport.Components.SuppressionWarning
  alias Plausible.Teams
  alias Plausible.Teams.Management.Roster

  def update(%{team: team}, socket) do
    {:ok, refresh_members(socket, team)}
  end

  def render(assigns) do
    ~H"""
    <div class="mt-2">
      <.table rows={Roster.sorted_for_display(@roster)}>
        <:thead>
          <.th>User</.th>
          <.th>Sessions</.th>
          <.th>Type</.th>
          <.th>Role</.th>
        </:thead>
        <:tbody :let={{_, member}}>
          <.td truncate>
            <div :if={not Roster.Entry.invitation?(member)} class="flex items-center">
              <.styled_link
                patch={~p"/cs/users/user/#{member.source.user.id}"}
                class="cursor-pointer flex block items-center"
              >
                <img
                  src={Plausible.Auth.User.profile_img_url(%Plausible.Auth.User{email: member.email})}
                  class="mr-4 w-6 rounded-full bg-gray-300"
                />
                {member.name} &lt;{member.email}&gt;
              </.styled_link>
              <.suppression_warning email={member.email} />
            </div>
            <div :if={Roster.Entry.invitation?(member)} class="flex items-center">
              <img
                src={Plausible.Auth.User.profile_img_url(%Plausible.Auth.User{email: member.email})}
                class="mr-4 w-6 rounded-full bg-gray-300"
              />
              {member.name} &lt;{member.email}&gt; <.suppression_warning email={member.email} />
            </div>
          </.td>
          <.td>
            {if Roster.Entry.invitation?(member),
              do: 0,
              else: @session_counts[member.source.user.id] || 0}
          </.td>
          <.td>
            <div class="flex items-center gap-x-1">
              <span :if={sso_member?(member)}>SSO </span>{member_type(member)}

              <.button
                :if={sso_member?(member)}
                id={"deprovision-sso-user-#{member.source.user.id}"}
                theme="ghost"
                size="sm"
                icon?={true}
                class="btn-text-danger"
                phx-click="deprovision-sso-user"
                phx-value-identifier={member.source.user.id}
                phx-target={@myself}
                data-confirm="Are you sure you want to deprovision SSO user and convert them to a standard user? This will sign them out and force to use regular e-mail/password combination to log in again."
              >
                <Heroicons.user_minus class="size-4" />
              </.button>
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

    success("SSO user deprovisioned")
    {:noreply, refresh_members(socket, socket.assigns.team)}
  end

  defp refresh_members(socket, team) do
    roster = Roster.init(team)

    users = for {_, %Roster.Entry{source: %Teams.Membership{user: user}}} <- roster, do: user

    session_counts =
      users
      |> Plausible.Auth.UserSessions.count_for_users()
      |> Enum.into(%{})

    assign(socket, team: team, roster: roster, session_counts: session_counts)
  end

  defp sso_member?(%Roster.Entry{source: %Teams.Membership{user: %{type: :sso}}}), do: true
  defp sso_member?(_), do: false

  defp member_type(member) do
    if Roster.Entry.invitation?(member), do: "invitation", else: "membership"
  end
end
