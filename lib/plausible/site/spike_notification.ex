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

  def changeset(settings, attrs \\ %{}) do
    settings
    |> cast(attrs, [:site_id, :recipients])
    |> validate_required([:site_id, :recipients])
    |> unique_constraint(:site)
  end

  def was_sent(schema) do
    schema
    |> change(last_sent: NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second))
  end

  def add_recipient(report, recipient) do
    report
    |> change(recipients: report.recipients ++ [recipient])
  end

  def remove_recipient(report, recipient) do
    report
    |> change(recipients: List.delete(report.recipients, recipient))
  end
end
