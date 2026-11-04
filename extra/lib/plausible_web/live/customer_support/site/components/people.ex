defmodule PlausibleWeb.CustomerSupport.Site.Components.People do
  @moduledoc """
  Site people component - handles site memberships and invitations
  """
  use PlausibleWeb, :live_component

  # capability:begin
  # id: cs_list_site_people@ui_session
  # action: cs_list_site_people
  # transport: ui_session
  # entry: live /cs/sites/site/:id?tab=people update
  # handler: PlausibleWeb.CustomerSupport.Site.Components.People.update/2
  # credential: [session]
  # resource: site
  # current_scope: none
  # current_scope_enforced_by: none
  # current_roles: [super_admin]
  # current_role_enforced_by: router pipeline :flags (SuperAdminOnlyPlug) + live_session :customer_support on_mount SuperAdminLiveAuth
  # current_feature_gate: none
  # proposed_scope: cs:read
  # proposed_roles: [super_admin]
  # confidence: verified
  # notes: Members and guests with emails
  # capability:end
  def update(%{site: site}, socket) do
    people = Plausible.Sites.list_people(site)

    people =
      (people.invitations ++ people.memberships)
      |> Enum.map(fn p ->
        if Map.has_key?(p, :invitation_id) do
          {:invitation, p.email, p.role}
        else
          {:membership, p.user, p.role}
        end
      end)

    {:ok, assign(socket, site: site, people: people)}
  end

  def render(assigns) do
    ~H"""
    <div class="mt-8">
      <.table rows={@people}>
        <:thead>
          <.th>User</.th>
          <.th>Kind</.th>
          <.th>Role</.th>
        </:thead>
        <:tbody :let={{kind, person, role}}>
          <.td :if={kind == :membership}>
            <.styled_link
              class="flex items-center"
              patch={~p"/cs/users/user/#{person.id}"}
            >
              <img
                src={Plausible.Auth.User.profile_img_url(person)}
                class="w-4 rounded-full bg-gray-300 mr-2"
              />
              {person.name}
            </.styled_link>
          </.td>

          <.td :if={kind == :invitation}>
            <div class="flex items-center">
              <img
                src={Plausible.Auth.User.profile_img_url(person)}
                class="w-4 rounded-full bg-gray-300 mr-2"
              />
              {person}
            </div>
          </.td>

          <.td :if={kind == :membership}>
            Membership
          </.td>

          <.td :if={kind == :invitation}>
            Invitation
          </.td>

          <.td>{role}</.td>
        </:tbody>
      </.table>
    </div>
    """
  end
end
