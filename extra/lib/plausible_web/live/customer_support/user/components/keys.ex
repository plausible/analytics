defmodule PlausibleWeb.CustomerSupport.User.Components.Keys do
  @moduledoc """
  User API keys component - handles displaying user's API keys
  """
  use PlausibleWeb, :live_component
  import PlausibleWeb.Components.Generic
  import Ecto.Query
  alias Plausible.Repo

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
            <.styled_link patch={"/cs/teams/#{api_key.team.id}"}>
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
