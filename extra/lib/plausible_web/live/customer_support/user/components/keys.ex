defmodule PlausibleWeb.CustomerSupport.User.Components.Keys do
  @moduledoc """
  User API keys component - handles displaying user's API keys
  """
  use PlausibleWeb, :live_component
  import Ecto.Query
  alias Plausible.Repo

  # capability:begin
  # id: cs_list_user_api_keys@ui_session
  # action: cs_list_user_api_keys
  # transport: ui_session
  # entry: live /cs/users/user/:id?tab=keys update
  # handler: PlausibleWeb.CustomerSupport.User.Components.Keys.update/2
  # credential: [session]
  # resource: account
  # current_scope: none
  # current_scope_enforced_by: none
  # current_roles: [super_admin]
  # current_role_enforced_by: router pipeline :flags (SuperAdminOnlyPlug) + live_session :customer_support on_mount SuperAdminLiveAuth
  # current_feature_gate: none
  # proposed_scope: cs:read
  # proposed_roles: [super_admin]
  # confidence: verified
  # notes: Key names, teams, scopes and key prefixes, not the keys
  # capability:end
  def update(%{user: user}, socket) do
    keys = keys(user)
    {:ok, assign(socket, user: user, keys: keys)}
  end

  def render(assigns) do
    ~H"""
    <div class="mt-8">
      <.table rows={@keys}>
        <:thead>
          <.th>Team</.th>
          <.th>Name</.th>
          <.th>Scopes</.th>
          <.th>Prefix</.th>
        </:thead>
        <:tbody :let={api_key}>
          <.td :if={is_nil(api_key.team)}>N/A</.td>
          <.td :if={api_key.team}>
            <.styled_link patch={~p"/cs/teams/team/#{api_key.team.id}"}>
              {api_key.team.name}
            </.styled_link>
          </.td>
          <.td>{api_key.name}</.td>
          <.td>
            {api_key.scopes}
          </.td>
          <.td>{api_key.key_prefix}</.td>
        </:tbody>
      </.table>
    </div>
    """
  end

  defp keys(user) do
    from(
      key in Plausible.Auth.ApiKey,
      where: key.user_id == ^user.id,
      preload: :team
    )
    |> Repo.all()
  end
end
