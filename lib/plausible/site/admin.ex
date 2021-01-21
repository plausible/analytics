defmodule Plausible.SiteAdmin do
  use Plausible.Repo

  def search_fields(_schema) do
    [
      :domain,
      members: [:name, :email]
    ]
  end

  def custom_index_query(_conn, _schema, query) do
    from(r in query, preload: [:members])
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
      members: %{value: fn s -> Enum.map(s.members, & &1.email) |> Enum.join(", ") end}
    ]
  end
end
