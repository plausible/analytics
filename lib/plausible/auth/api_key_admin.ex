defmodule Plausible.Auth.ApiKeyAdmin do
  @moduledoc """
  Stats and Sites API key logic for CRM.
  """
  use Plausible.Repo

  alias Plausible.Auth
  alias Plausible.Teams

  def search_fields(_schema) do
    [
      :name,
      user: [:name, :email],
      team: [:name, :identifier]
    ]
  end

  def custom_index_query(_conn, _schema, query) do
    from(r in query, preload: [:user, team: :owners])
  end

  def create_changeset(_schema, attrs) do
    team = Teams.get(attrs["team_identifier"])

    user_id =
      case Integer.parse(Map.get(attrs, "user_id", "")) do
        {user_id, ""} -> user_id
        _ -> nil
      end

    user = user_id && Auth.find_user_by(id: user_id)

    team =
      case {team, user} do
        {%{} = team, _} ->
          team

        {nil, %{} = user} ->
          {:ok, team} = Teams.get_or_create(user)

          team

        _ ->
          nil
      end

    Auth.ApiKey.changeset(%Auth.ApiKey{}, team, attrs)
  end

  def update_changeset(entry, attrs) do
    Auth.ApiKey.update(entry, attrs)
  end

  @plaintext_key_help """
  The value of the API key is sensitive data like a password. Once created, the value of they will never be revealed again. Make sure to copy/paste this into a secure place before hitting 'save'. When sending the key to a customer, use a secure E2EE system that destructs the message after a certain period like https://bitwarden.com/products/send
  """

  @team_identifier_help """
  Team under which the key is to be created. Defaults to user's personal team when left empty.
  """

  def form_fields(_) do
    [
      name: nil,
      key: %{create: :readonly, update: :hidden, help_text: @plaintext_key_help},
      key_prefix: %{create: :hidden, update: :readonly},
      scopes: %{
        choices: [
          {"Stats API", Jason.encode!(["stats:read:*"])},
          {"Sites API", Jason.encode!(["sites:provision:*"])}
        ]
      },
      team_identifier: %{update: :hidden, help_text: @team_identifier_help},
      user_id: nil
    ]
  end

  def index(_) do
    [
      key_prefix: nil,
      name: nil,
      scopes: nil,
      owner: %{value: &get_owner/1},
      team: %{value: &get_team/1}
    ]
  end

  defp get_team(api_key) do
    team_name =
      case api_key.team && api_key.team.owners do
        [owner] ->
          if api_key.team.setup_complete do
            api_key.team.name
          else
            owner.name
          end

        [_ | _] ->
          api_key.team.name

        nil ->
          "(none)"
      end
      |> html_escape()

    if api_key.team do
      Phoenix.HTML.raw("""
      <a href="/crm/teams/team/#{api_key.team.id}">#{team_name}</a>
      """)
    else
      team_name
    end
  end

  defp get_owner(api_key) do
    escaped_name = html_escape(api_key.user.name)
    escaped_email = html_escape(api_key.user.email)

    owner_html =
      """
       <a href="/crm/auth/user/#{api_key.user.id}">#{escaped_name}</a>
       <br/>
       #{escaped_email}
      """

    {:safe, owner_html}
  end

  defp html_escape(string) do
    string
    |> Phoenix.HTML.html_escape()
    |> Phoenix.HTML.safe_to_string()
  end
end
