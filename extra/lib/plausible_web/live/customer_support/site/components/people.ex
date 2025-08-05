defmodule PlausibleWeb.CustomerSupport.Site.Components.People do
  @moduledoc """
  Site people component - handles site memberships and invitations
  """
  use PlausibleWeb, :live_component

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
              patch={Routes.customer_support_user_path(PlausibleWeb.Endpoint, :show, person.id)}
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
                src={Plausible.Auth.User.profile_img_url("hum")}
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
