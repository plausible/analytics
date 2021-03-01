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

  def changeset(schema, attrs) do
    schema
    |> cast(attrs, [:site_id, :recipients, :threshold])
    |> validate_required([:site_id, :recipients, :threshold])
    |> unique_constraint(:site_id)
  end

  def add_recipient(schema, recipient) do
    schema
    |> change(recipients: schema.recipients ++ [recipient])
  end

  def remove_recipient(schema, recipient) do
    schema
    |> change(recipients: List.delete(schema.recipients, recipient))
  end

  def was_sent(schema) do
    schema
    |> change(last_sent: NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second))
  end
end
