defmodule Plausible.Auth.ApiKeyAdmin do
  use Plausible.Repo

  def search_fields(_schema) do
    [
      :name,
      user: [:name, :email]
    ]
  end

  def custom_index_query(_conn, _schema, query) do
    from(r in query, preload: [:user])
  end

  def create_changeset(schema, attrs) do
    scopes = [attrs["scope"]]
    Plausible.Auth.ApiKey.changeset(struct(schema, %{}), Map.merge(%{"scopes" => scopes}, attrs))
  end

  def update_changeset(schema, attrs) do
    Plausible.Auth.ApiKey.update(schema, attrs)
  end

  @plaintext_key_help """
  The value of the API key is sensitive data like a password. Once created, the value of they will never be revealed again. Make sure to copy/paste this into a secure place before hitting 'save'. When sending the key to a customer, use a secure E2EE system that destructs the message after a certain period like https://bitwarden.com/products/send
  """
  def form_fields(_) do
    [
      name: nil,
      key: %{create: :readonly, update: :hidden, help_text: @plaintext_key_help},
      key_prefix: %{create: :hidden, update: :readonly},
      hourly_request_limit: %{default: 1000},
      scope: %{choices: [{"Stats API", ["stats:read:*"]}, {"Sites API", ["sites:provision:*"]}]},
      user_id: nil
    ]
  end

  def index(_) do
    [
      key_prefix: nil,
      name: nil,
      scopes: nil,
      owner: %{value: & &1.user.email}
    ]
  end
end
