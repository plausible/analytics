defmodule Plausible.SiteAdmin do
  use Plausible.Repo

  def search_fields(_schema) do
    [
      :domain,
      members: [:name, :email]
    ]
  end

  def custom_index_query(_conn, _schema, query) do
    from(r in query, preload: [memberships: :user])
  end

  def form_fields(_) do
    [
      domain: nil,
      timezone: nil,
      public: nil
    ]
  end

  def index(_) do
    [
      domain: nil,
      timezone: nil,
      public: nil,
      owner: %{value: &get_owner_email/1},
      other_members: %{value: &get_other_members_emails/1}
    ]
  end

  defp get_owner_email(site) do
    Enum.find(site.memberships, fn m -> m.role == :owner end).user.email
  end

  defp get_other_members_emails(site) do
    memberships = Enum.reject(site.memberships, fn m -> m.role == :owner end)
    Enum.map(memberships, fn m -> m.user.email end) |> Enum.join(", ")
  end
end
