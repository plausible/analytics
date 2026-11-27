defmodule Plausible.Billing.PaddleBilling.Webhooks do
  @moduledoc """
  Handles Paddle Billing `subscription.created` and `subscription.updated` events.

  Both events carry the full subscription, so they share one code path:

    * Every event is stored in `billing_subscription_events`. A repeated
      `event_id` is a duplicate delivery and is ignored.
    * Paddle doesn't guarantee ordering. An event older than the latest
      stored event of the same subscription is recorded but not applied.
    * `subscription.created` resolves the team from `custom_data`
      (`team_id`, or `user_id` for a new "My Personal Sites" team) and links it
      to the Paddle customer. `subscription.updated` finds the subscription by id.

  Events of one team are processed one at a time, under an advisory lock on the
  team. Without it, two events handled at once could not see each other, and
  the older one could overwrite the newer state.

  A subscription with a scheduled cancellation is stored as `:deleted`, with
  `next_bill_date` set to the moment the cancellation takes effect. This
  matches how Classic cancellations behave: access lasts until that date.

  An event that fails after verification is kept in `billing_webhook_failures`,
  outside the rolled back transaction, so it can be inspected.

  See https://developer.paddle.com/webhooks/subscriptions/subscription-created
  and https://developer.paddle.com/webhooks/subscriptions/subscription-updated
  """

  use Plausible.Repo

  require Plausible.Billing.Subscription.Status

  alias Plausible.Auth
  alias Plausible.Billing.PaddleBilling.{Subscription, SubscriptionEvent, WebhookFailure}
  alias Plausible.Billing.Subscription.Status
  alias Plausible.Billing.SubscriptionState
  alias Plausible.Teams

  @type result() :: {:ok, :applied | :stale | :duplicate} | {:error, term()}

  @spec subscription_created(map()) :: result()
  def subscription_created(event), do: handle(:created, event)

  @spec subscription_updated(map()) :: result()
  def subscription_updated(event), do: handle(:updated, event)

  defp handle(kind, event) do
    case Repo.transact(fn -> process(kind, event) end) do
      {:error, :duplicate} ->
        {:ok, :duplicate}

      {:error, reason} = error ->
        record_failure(event, reason)
        error

      other ->
        other
    end
  end

  defp record_failure(event, reason) do
    Repo.insert!(%WebhookFailure{
      billing_event_id: event["event_id"],
      event_type: event["event_type"],
      payload: event,
      error: inspect(reason)
    })
  end

  defp process(kind, %{"event_id" => event_id, "data" => %{} = data} = event) do
    with {:ok, occurred_at} <- parse_datetime(event["occurred_at"]),
         {:ok, attrs} <- subscription_attrs(data, occurred_at),
         :ok <- lock_team_or_user(kind, data, attrs),
         :ok <- check_not_seen(event_id),
         {:ok, existing} <- find_existing(kind, attrs.billing_subscription_id),
         {:ok, team} <- resolve_team(kind, existing, data),
         :ok <- record_event(event, attrs, team, occurred_at) do
      if stale?(attrs.billing_subscription_id, event_id, occurred_at) do
        {:ok, :stale}
      else
        apply_subscription(kind, existing, team, attrs)
      end
    end
  end

  defp process(_kind, _event), do: {:error, :invalid_event}

  defp lock_team_or_user(kind, data, attrs) do
    if lock_id = id_to_lock(kind, data, attrs) do
      Repo.query!("SELECT pg_advisory_xact_lock(hashtext($1))", [lock_id])
    end

    :ok
  end

  defp id_to_lock(:created, %{"custom_data" => %{"team_id" => team_id}}, _attrs) do
    if team_id = parse_id(team_id) do
      "paddle_billing_team:#{parse_id(team_id)}"
    end
  end

  defp id_to_lock(:created, %{"custom_data" => %{"user_id" => user_id}}, _attrs) do
    if user_id = parse_id(user_id) do
      "paddle_billing_user:#{parse_id(user_id)}"
    end
  end

  defp id_to_lock(:created, _data, _attrs), do: nil

  defp id_to_lock(:updated, _data, attrs) do
    case Repo.get_by(Subscription, billing_subscription_id: attrs.billing_subscription_id) do
      %Subscription{team_id: team_id} -> "paddle_billing_team:#{team_id}"
      nil -> nil
    end
  end

  defp check_not_seen(event_id) do
    if Repo.exists?(from e in SubscriptionEvent, where: e.billing_event_id == ^event_id) do
      {:error, :duplicate}
    else
      :ok
    end
  end

  defp find_existing(kind, billing_subscription_id) do
    existing = Repo.get_by(Subscription, billing_subscription_id: billing_subscription_id)

    case {kind, existing} do
      {:updated, nil} -> {:error, :subscription_not_found}
      _ -> {:ok, existing}
    end
  end

  defp resolve_team(:updated, %Subscription{team_id: team_id}, _data) do
    {:ok, Repo.get!(Teams.Team, team_id)}
  end

  defp resolve_team(:created, _existing, %{"custom_data" => %{} = custom_data}) do
    team_id = parse_id(custom_data["team_id"])
    user_id = parse_id(custom_data["user_id"])

    cond do
      team_id -> find_team(team_id)
      user_id -> create_personal_team(user_id)
      true -> {:error, :invalid_custom_data}
    end
  end

  defp resolve_team(:created, _existing, _data), do: {:error, :invalid_custom_data}

  defp find_team(team_id) do
    case Teams.get(team_id) do
      nil -> {:error, :team_not_found}
      team -> {:ok, team}
    end
  end

  defp create_personal_team(user_id) do
    case Repo.get(Auth.User, user_id) do
      nil ->
        {:error, :user_not_found}

      user ->
        # Always a new team, as in Classic: a subscription paid by a guest or
        # a non-owner must not shadow the subscription of a team they own
        {:ok, Teams.force_create_my_team(user)}
    end
  end

  defp parse_id(id) when is_integer(id) and id > 0, do: id

  defp parse_id(id) when is_binary(id) do
    case Integer.parse(id) do
      {id, ""} when id > 0 -> id
      _ -> nil
    end
  end

  defp parse_id(_), do: nil

  defp record_event(event, attrs, team, occurred_at) do
    event_attrs =
      attrs
      |> Map.take(Subscription.fields())
      |> Map.merge(%{
        billing_event_id: event["event_id"],
        original_event_type: event["event_type"],
        original_event: event,
        occurred_at: occurred_at,
        team_id: team.id
      })

    changeset = SubscriptionEvent.changeset(%SubscriptionEvent{}, event_attrs)

    case Repo.insert(changeset, on_conflict: :nothing, conflict_target: :billing_event_id) do
      {:ok, %{id: nil}} -> {:error, :duplicate}
      {:ok, _} -> :ok
      {:error, changeset} -> {:error, {:invalid_event, changeset.errors}}
    end
  end

  # Paddle doesn't guarantee delivery order. An event is stale when another event
  # of the same subscription, with a later `occurred_at`, is already stored.
  defp stale?(billing_subscription_id, event_id, occurred_at) do
    latest =
      Repo.one(
        from e in SubscriptionEvent,
          where: e.billing_subscription_id == ^billing_subscription_id,
          where: e.billing_event_id != ^event_id,
          select: max(e.occurred_at)
      )

    not is_nil(latest) and NaiveDateTime.compare(latest, occurred_at) == :gt
  end

  defp apply_subscription(kind, existing, team, attrs) do
    link_customer(team, attrs.billing_customer_id)

    subscription = upsert_subscription(kind, existing, team, attrs)

    subscription
    |> SubscriptionState.apply_subscription_state()
    |> maybe_notify_cancellation(kind, existing, subscription)

    {:ok, :applied}
  end

  defp link_customer(team, customer_id) do
    Repo.update_all(from(t in Teams.Team, where: t.id == ^team.id),
      set: [billing_customer_id: customer_id]
    )
  end

  defp upsert_subscription(:created, _existing, team, attrs) do
    %Subscription{team_id: team.id}
    |> Subscription.changeset(attrs)
    |> Repo.insert!(
      on_conflict: {:replace, Subscription.fields() ++ [:updated_at]},
      conflict_target: :team_id,
      returning: true
    )
  end

  defp upsert_subscription(:updated, existing, _team, attrs) do
    existing
    |> Subscription.changeset(attrs)
    |> Repo.update!()
  end

  defp maybe_notify_cancellation(
         team,
         :updated,
         %{status: previous},
         %{status: Status.deleted()}
       )
       when previous != Status.deleted() do
    SubscriptionState.notify_cancellation(team)
  end

  defp maybe_notify_cancellation(team, _kind, _existing, _subscription), do: team

  defp subscription_attrs(data, occurred_at) do
    with {:ok, status} <- status(data),
         {:ok, item} <- first_item(data),
         {:ok, interval} <- interval(item) do
      {:ok,
       %{
         billing_subscription_id: data["id"],
         billing_customer_id: data["customer_id"],
         billing_product_id: item["price"]["product_id"],
         billing_price_id: item["price"]["id"],
         billing_interval: interval,
         next_bill_amount: next_bill_amount(item, data["currency_code"]),
         next_bill_date: next_bill_date(data, status, occurred_at),
         last_bill_date: to_date(get_in(data, ["current_billing_period", "starts_at"])),
         currency_code: data["currency_code"],
         status: status
       }}
    end
  end

  defp status(%{"status" => status} = data) do
    cancellation_scheduled? = get_in(data, ["scheduled_change", "action"]) == "cancel"

    case {status, cancellation_scheduled?} do
      {"canceled", _} -> {:ok, Status.deleted()}
      {status, true} when status in ~w(active past_due paused) -> {:ok, Status.deleted()}
      {"active", _} -> {:ok, Status.active()}
      {"past_due", _} -> {:ok, Status.past_due()}
      {"paused", _} -> {:ok, Status.paused()}
      _ -> {:error, {:unsupported_status, status}}
    end
  end

  defp status(_), do: {:error, :invalid_event}

  defp first_item(%{"items" => [%{"price" => %{"id" => _, "product_id" => _}} = item | _]}),
    do: {:ok, item}

  defp first_item(_), do: {:error, :invalid_event}

  defp interval(%{"price" => %{"billing_cycle" => %{"interval" => "month", "frequency" => 1}}}),
    do: {:ok, :monthly}

  defp interval(%{"price" => %{"billing_cycle" => %{"interval" => "year", "frequency" => 1}}}),
    do: {:ok, :yearly}

  defp interval(item), do: {:error, {:unsupported_billing_cycle, item["price"]["billing_cycle"]}}

  defp next_bill_date(data, status, occurred_at) do
    cancellation_effective_at =
      if status == Status.deleted(), do: get_in(data, ["scheduled_change", "effective_at"])

    Enum.find_value(
      [
        cancellation_effective_at,
        data["next_billed_at"],
        get_in(data, ["current_billing_period", "ends_at"]),
        data["paused_at"],
        data["canceled_at"]
      ],
      NaiveDateTime.to_date(occurred_at),
      &to_date/1
    )
  end

  # `unit_price.amount` is in the lowest denomination of the currency. When the
  # price has an override in the subscription's currency, that one is charged.
  defp next_bill_amount(%{"price" => price} = item, currency_code) do
    unit_price =
      Enum.find_value(price["unit_price_overrides"] || [], price["unit_price"], fn override ->
        override["unit_price"]["currency_code"] == currency_code && override["unit_price"]
      end)

    digits = Cldr.Currency.currency_for_code!(currency_code).digits

    unit_price["amount"]
    |> Decimal.new()
    |> Decimal.div(Integer.pow(10, digits))
    |> Decimal.mult(item["quantity"] || 1)
    |> Decimal.round(digits)
    |> Decimal.to_string(:normal)
  end

  defp parse_datetime(datetime) when is_binary(datetime) do
    case NaiveDateTime.from_iso8601(datetime) do
      {:ok, datetime} -> {:ok, datetime}
      _ -> {:error, :invalid_event}
    end
  end

  defp parse_datetime(_), do: {:error, :invalid_event}

  defp to_date(nil), do: nil

  defp to_date(datetime) when is_binary(datetime) do
    case NaiveDateTime.from_iso8601(datetime) do
      {:ok, datetime} -> NaiveDateTime.to_date(datetime)
      _ -> nil
    end
  end
end
