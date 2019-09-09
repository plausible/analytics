defmodule Plausible.Site.WeeklyReport do
  use Ecto.Schema
  import Ecto.Changeset
  @mail_regex ~r/^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,4}$/

  schema "weekly_reports" do
    field :email, :string
    belongs_to :site, Plausible.Site

    timestamps()
  end

  def changeset(settings, attrs \\ %{}) do
    settings
    |> cast(attrs, [:site_id, :email])
    |> validate_required([:site_id, :email])
    |> validate_format(:email, @mail_regex)
    |> unique_constraint(:site)
  end
end
