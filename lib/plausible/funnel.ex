defmodule Plausible.Funnel do
  use Ecto.Schema

  @type t() :: %__MODULE__{}
  schema "funnels" do
    field :name, :string
    belongs_to :site, Plausible.Site

    has_many :funnel_goals, Plausible.Funnel.Goals
    has_many :goals, through: [:funnel_goals, :goal]
    timestamps()
  end
end
