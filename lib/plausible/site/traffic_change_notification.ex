defmodule Plausible.Site.TrafficChangeNotification do
  @moduledoc """
  Configuration schema for site-specific traffic change notifications.
  """
  use Ecto.Schema
  import Ecto.Changeset

  # legacy table name since traffic drop notifications were introduced
  schema "spike_notifications" do
    field :recipients, {:array, :string}
    field :threshold, :integer
    field :last_sent, :naive_datetime
    field :type, Ecto.Enum, values: [:spike, :drop], default: :spike
    belongs_to :site, Plausible.Site

    timestamps()
  end

  def changeset(schema, attrs) do
    schema
    |> cast(attrs, [:site_id, :recipients, :threshold, :type])
    |> validate_required([:site_id, :recipients, :threshold, :type])
    |> validate_number(:threshold, greater_than_or_equal_to: 1)
    |> unique_constraint([:site_id, :type])
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
