defmodule Plausible.PendingStatsDeletion do
  @moduledoc """
  Schema for tracking pending deletions from ClickHouse
  """

  use Ecto.Schema

  import Ecto.Changeset

  @reasons [:user_request]

  @type t() :: %__MODULE__{}

  schema "pending_stats_deletions" do
    field :site_id, :integer
    field :stats_start_date, :date
    field :stats_end_date, :date
    field :reason, Ecto.Enum, values: @reasons, default: :user_request

    timestamps()
  end

  @fields [:site_id, :stats_start_date, :stats_end_date, :reason]

  def changeset(pending_stats_deletion \\ %__MODULE__{}, attrs \\ %{}) do
    pending_stats_deletion
    |> cast(attrs, @fields)
    |> validate_required([:site_id, :reason])
  end
end
