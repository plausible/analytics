defmodule Plausible.SiteAdmin do
  use Plausible.Repo

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
      members: %{value: fn s -> Enum.map(s.members, & &1.email) end}
    ]
  end
end
