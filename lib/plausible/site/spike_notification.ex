defmodule Plausible.Site.SpikeNotification do
  use Ecto.Schema
  import Ecto.Changeset

  schema "spike_notifications" do
    field :recipients, {:array, :string}
    field :threshold, :integer
    field :last_sent, :naive_datetime
    belongs_to :site, Plausible.Site

    timestamps()
  end

  def was_sent(schema) do
    schema
    |> change(last_sent: NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second))
  end
end
