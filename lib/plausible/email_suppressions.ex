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

  @page_size 50

  @doc """
  List suppressions, most recent first - for manual review (CRM).
  """
  @spec list(keyword(), map()) :: Paginator.Page.t()
  def list(filters \\ [], pagination_params \\ %{}) do
    EmailSuppression
    |> filter_reason(Keyword.get(filters, :reason))
    |> filter_search(Keyword.get(filters, :search))
    |> order_by([s], desc: s.inserted_at, desc: s.id)
    |> preload(:reactivated_by)
    |> Plausible.Pagination.paginate(
      pagination_params,
      cursor_fields: [inserted_at: :desc, id: :desc],
      limit: @page_size
    )
  end

  defp filter_reason(query, reason) when reason in [nil, ""], do: query
  defp filter_reason(query, reason), do: where(query, [s], s.reason == ^reason)

  defp filter_search(query, search) when search in [nil, ""], do: query

  defp filter_search(query, search) do
    where(query, [s], ilike(s.email, ^"%#{search}%"))
  end

  @doc """
  Lifts a suppression after manual review, recording who did it.
  Encapsulates suppression remote deletion at Postmark - can't be done for spam complaints.
  """
  @spec reactivate(String.t(), Plausible.Auth.User.t()) ::
          {:ok, EmailSuppression.t()}
          | {:error,
             :not_found
             | :cannot_delete_spam_complaint
             | {:postmark_error, term()}
             | Ecto.Changeset.t()}
  def reactivate(email, %Plausible.Auth.User{id: user_id}) do
    case Repo.get_by(EmailSuppression, email: email) do
      nil ->
        {:error, :not_found}

      suppression ->
        with :ok <- delete_in_postmark(suppression) do
          suppression
          |> EmailSuppression.reactivate_changeset(user_id)
          |> Repo.update()
        end
    end
  end

  defp delete_in_postmark(%{reason: :spam_complaint}) do
    {:error, :cannot_delete_spam_complaint}
  end

  defp delete_in_postmark(%{email: email}) do
    case Plausible.Postmark.delete_suppression(email) do
      :ok -> :ok
      {:error, reason} -> {:error, {:postmark_error, reason}}
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
