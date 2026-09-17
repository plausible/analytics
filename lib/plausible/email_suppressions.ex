defmodule Plausible.EmailSuppressions do
  @moduledoc """
  Tracks email addresses we should not attempt to send transactional mail to
  and guards `Plausible.Mailer` against sending to them.

  Entries are created from Postmark bounce/spam-complaint webhooks and from a
  one-off backfill against the Postmark Bounce API. A suppression is lifted by
  a manual review (e.g. via the customer support module), which is recorded
  as a `reactivated_at`/`reactivated_by_user_id` pair on the record.
  """

  import Ecto.Query

  alias Plausible.EmailSuppression
  alias Plausible.Repo

  @replace_on_conflict [
    :reason,
    :source,
    :postmark_bounce_id,
    :postmark_inactive,
    :can_activate,
    :details,
    :reactivated_at,
    :reactivated_by_user_id,
    :updated_at
  ]

  @doc """
  Returns whether the given e-mail address is currently suppressed, i.e.
  whether `Plausible.Mailer` should refuse to send to it.

  A suppression that has been manually reactivated is no longer considered
  suppressed.
  """
  @spec suppressed?(String.t()) :: boolean()
  def suppressed?(email) when is_binary(email) do
    EmailSuppression
    |> where([s], s.email == ^email and is_nil(s.reactivated_at))
    |> Repo.exists?()
  end

  @doc """
  Records (or refreshes) a suppression originating from a Postmark bounce.

  If the address is already suppressed, the record is refreshed with the
  latest bounce details. If the address had been manually
  reactivated previously, the new bounce takes precedence and re-suppresses it.
  """
  @spec create_from_bounce(map()) :: {:ok, EmailSuppression.t()} | {:error, Ecto.Changeset.t()}
  def create_from_bounce(attrs) do
    attrs
    |> Map.take([
      :email,
      :reason,
      :source,
      :postmark_bounce_id,
      :postmark_inactive,
      :can_activate,
      :details
    ])
    |> upsert()
  end

  @doc """
  Records (or refreshes) a suppression originating from Postmark spam
  complaint.
  """
  @spec create_from_spam_complaint(map()) ::
          {:ok, EmailSuppression.t()} | {:error, Ecto.Changeset.t()}
  def create_from_spam_complaint(attrs) do
    attrs
    |> Map.take([
      :email,
      :source,
      :postmark_bounce_id,
      :postmark_inactive,
      :can_activate,
      :details
    ])
    |> Map.put(:reason, :spam_complaint)
    |> upsert()
  end

  @doc """
  Lifts a suppression after manual review, recording who did it.
  """
  @spec reactivate(String.t(), Plausible.Auth.User.t()) ::
          {:ok, EmailSuppression.t()} | {:error, :not_found | Ecto.Changeset.t()}
  def reactivate(email, %Plausible.Auth.User{id: user_id}) do
    case Repo.get_by(EmailSuppression, email: email) do
      nil ->
        {:error, :not_found}

      suppression ->
        suppression
        |> EmailSuppression.reactivate_changeset(user_id)
        |> Repo.update()
    end
  end

  defp upsert(attrs) do
    %EmailSuppression{}
    |> EmailSuppression.changeset(attrs)
    |> Repo.insert(
      on_conflict: {:replace, @replace_on_conflict},
      conflict_target: :email
    )
  end
end
