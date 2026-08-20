defmodule Plausible.PendingStatsDeletion do
  @moduledoc """
  Schema for tracking pending deletions from ClickHouse
  """

  use Ecto.Schema

  @reasons [:user_request, :inactive_trial, :inactive_subscription]

  @type t() :: %__MODULE__{}

  schema "pending_stats_deletions" do
    field :site_id, :integer
    field :reason, Ecto.Enum, values: @reasons, default: :user_request

    timestamps()
  end
end
