defmodule Plausible.EmailSuppression do
  @moduledoc """
  A record of email addresses we should not send transactional mail to,
  because Postmark has reported it as bouncing or complaining.
  """

  use Ecto.Schema

  import Ecto.Changeset

  @type t() :: %__MODULE__{}

  @reasons [:hard_bounce, :bad_email_address, :blocked, :spam_complaint, :manual]
  @sources [:webhook, :backfill, :manual]

  schema "email_suppressions" do
    field :email, :string
    field :reason, Ecto.Enum, values: @reasons
    field :source, Ecto.Enum, values: @sources
    # so we can look the bounce back up via e.g. /bounces API
    field :postmark_bounce_id, :integer

    # Mirrors Postmark's own `Inactive` flag: refusal to send to
    # this address itself once true, independently of our internal records
    field :postmark_inactive, :boolean, default: false

    # Mirrors Postmark's own `CanActivate` flag. Some bounce types
    # are permanent on Postmark's end
    field :can_activate, :boolean, default: false

    # Postmark's short human-readable explanation for the bounce (`Details` field), 
    # kept for context when under manual CS inspection
    field :details, :string

    # Set once CS has manually cleared this suppression after review.
    # A date value here means the address is not suppressed anymore
    field :reactivated_at, :naive_datetime

    belongs_to :reactivated_by, Plausible.Auth.User, foreign_key: :reactivated_by_user_id

    timestamps()
  end

  @required [:email, :reason, :source]
  @optional [:postmark_bounce_id, :postmark_inactive, :can_activate, :details]

  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(suppression, attrs) do
    suppression
    |> cast(attrs, @required ++ @optional)
    |> validate_required(@required)
    |> unique_constraint(:email)
  end

  @spec reactivate_changeset(t(), pos_integer()) :: Ecto.Changeset.t()
  def reactivate_changeset(suppression, user_id) do
    change(suppression,
      reactivated_at: NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second),
      reactivated_by_user_id: user_id
    )
  end
end
