defmodule Plausible.Billing.MigrationAudit.Subscribers do
  @moduledoc """
  Part of the Paddle Billing migration audit fetched from local db.
  How subscribers are distributed by status, what they effectively
  pay, and how enterprise (customer-specific) plans look. Read-only, and all
  output is aggregated, no customer identifiers.

  See `Plausible.Billing.MigrationAudit`
  """

  use Plausible.Repo

  import Ecto.Query, only: [from: 2]

  require Plausible.Billing.Subscription.Status

  alias Plausible.Billing.{EnterprisePlan, Plan, Plans, Subscription}
  alias Plausible.Billing.Subscription.Status
  alias Plausible.Teams.Team

  @free_plan_id "free_10k"

  @doc """
  Returns a map with the following keys:

    * `:statuses` - the current subscription of every team, by status. Cancelled
      subscriptions are split into those still inside the paid period and those
      that expired. `:teams_on_app_trial` are teams in our own trial without
      any subscription
    * `:billed` - live subscriptions (active, past due, paused, or cancelled but
      paid up) by kind, currency and interval: the effective amount paid.
    * `:vs_list_price` - for regular plans, how the amount paid compares to the
      list price in `plan_prices.json`, by currency. The number is compared
      as is, so for EUR and GBP "equal" means parity with the USD price. Anything
      that isn't equal is a discount, a modifier, a negotiated price or a
      grandfathered one. `:off_list_price_points` lists the most common ones.
    * `:enterprise` - live enterprise plans: price points (distinct currency,
      interval and amount combinations), by interval, and how many plans are
      shared or repeated.

  Options:

    * `:today` - date for "inside the paid period" (default: today, UTC).
    * `:list_prices` - map of plan id => USD list price (default:
      `plan_prices.json` from `priv`).
  """
  @spec audit(Keyword.t()) :: map()
  def audit(opts \\ []) do
    today = Keyword.get(opts, :today, Date.utc_today())
    list_prices = Keyword.get_lazy(opts, :list_prices, &read_list_prices/0)

    rows = live_rows(today)

    %{
      as_of: today,
      statuses: statuses(today),
      billed: billed(rows),
      vs_list_price: vs_list_price(rows, list_prices),
      enterprise: enterprise(rows)
    }
  end

  defp statuses(today) do
    current =
      from(s in Subscription,
        distinct: s.team_id,
        order_by: [asc: s.team_id, desc: s.inserted_at, desc: s.id],
        select: {s.paddle_plan_id, s.status, s.next_bill_date}
      )
      |> Repo.all()

    by_status =
      current
      |> Enum.frequencies_by(&status_label(&1, today))
      |> Enum.map(fn {status, teams} -> %{status: status, teams: teams} end)
      |> Enum.sort_by(&{-&1.teams, &1.status})

    %{
      teams_with_subscription: length(current),
      by_status: by_status,
      teams_on_app_trial: teams_on_app_trial(today)
    }
  end

  defp status_label({@free_plan_id, _status, _date}, _today), do: "free_10k"

  defp status_label({plan_id, status, date}, today) do
    cond do
      plan_id == Subscription.manual_plan_id() ->
        "manual"

      (status == Status.deleted() and date) && Date.compare(date, today) != :lt ->
        "cancelled_paid_up"

      status == Status.deleted() ->
        "cancelled_expired"

      true ->
        Atom.to_string(status)
    end
  end

  defp teams_on_app_trial(today) do
    from(t in Team,
      as: :team,
      where: t.trial_expiry_date >= ^today,
      where: not exists(from(s in Subscription, where: s.team_id == parent_as(:team).id)),
      select: count(t.id)
    )
    |> Repo.one()
  end

  # Live, paid subscriptions with the plan resolved the way the app does it.
  defp live_rows(today) do
    live = [Status.active(), Status.past_due(), Status.paused()]

    from(s in Subscription,
      where: s.status in ^live or (s.status == ^Status.deleted() and s.next_bill_date >= ^today),
      where: s.paddle_plan_id not in [^@free_plan_id, ^Subscription.manual_plan_id()],
      order_by: [asc: s.id]
    )
    |> Repo.all()
    |> Enum.map(fn subscription ->
      plan = Plans.get_subscription_plan(subscription)

      %{
        plan_id: subscription.paddle_plan_id,
        currency: subscription.currency_code,
        amount: parse_amount(subscription.next_bill_amount),
        kind: kind(plan),
        interval: interval(plan, subscription)
      }
    end)
  end

  defp kind(%EnterprisePlan{}), do: :enterprise
  defp kind(%Plan{}), do: :regular
  defp kind(_), do: :unresolved

  defp interval(%EnterprisePlan{billing_interval: interval}, _subscription), do: interval

  defp interval(%Plan{monthly_product_id: id}, %{paddle_plan_id: id}), do: :monthly
  defp interval(%Plan{}, _subscription), do: :yearly
  defp interval(_plan, _subscription), do: :unknown

  defp billed(rows) do
    rows
    |> Enum.group_by(&{&1.kind, &1.currency, &1.interval})
    |> Enum.map(fn {{kind, currency, interval}, group} ->
      amounts = for %{amount: {:ok, amount}} <- group, do: amount

      %{
        kind: kind,
        currency: currency,
        interval: interval,
        subscriptions: length(group),
        unparsable_amounts: length(group) - length(amounts)
      }
      |> Map.merge(amount_stats(amounts))
    end)
    |> Enum.sort_by(&{-&1.subscriptions, &1.kind, &1.currency, &1.interval})
  end

  defp amount_stats([]), do: %{total: nil, min: nil, max: nil}

  defp amount_stats(amounts) do
    %{
      total: amounts |> Enum.reduce(&Decimal.add/2) |> format(),
      min: amounts |> Enum.reduce(&Decimal.min/2) |> format(),
      max: amounts |> Enum.reduce(&Decimal.max/2) |> format()
    }
  end

  defp vs_list_price(rows, list_prices) do
    regular = Enum.filter(rows, &(&1.kind == :regular))

    compared =
      Enum.map(regular, fn row ->
        {row, compare(row.amount, Map.get(list_prices, row.plan_id))}
      end)

    by_currency =
      compared
      |> Enum.group_by(fn {row, _} -> row.currency end, fn {_, result} -> result end)
      |> Enum.map(fn {currency, results} ->
        frequencies = Enum.frequencies(results)

        %{
          currency: currency,
          subscriptions: length(results),
          equal: Map.get(frequencies, :equal, 0),
          lower: Map.get(frequencies, :lower, 0),
          higher: Map.get(frequencies, :higher, 0),
          no_list_price: Map.get(frequencies, :no_list_price, 0),
          unparsable: Map.get(frequencies, :unparsable, 0)
        }
      end)
      |> Enum.sort_by(&{-&1.subscriptions, &1.currency})

    off_list =
      for {row, result} <- compared, result in [:lower, :higher], reduce: %{} do
        acc ->
          key = {row.plan_id, row.currency, row.interval, format(elem(row.amount, 1)), result}
          Map.update(acc, key, 1, &(&1 + 1))
      end

    %{
      by_currency: by_currency,
      off_list_price_points:
        off_list
        |> Enum.map(fn {{plan_id, currency, interval, amount, result}, count} ->
          %{
            plan_id: plan_id,
            currency: currency,
            interval: interval,
            paid: amount,
            list_price: format(to_decimal(Map.fetch!(list_prices, plan_id))),
            comparison: result,
            subscriptions: count
          }
        end)
        |> Enum.sort_by(&{-&1.subscriptions, &1.plan_id})
        |> Enum.take(20)
    }
  end

  defp compare({:ok, _amount}, nil), do: :no_list_price
  defp compare(:error, _list_price), do: :unparsable

  defp compare({:ok, amount}, list_price) do
    case Decimal.compare(amount, to_decimal(list_price)) do
      :eq -> :equal
      :lt -> :lower
      :gt -> :higher
    end
  end

  defp enterprise(rows) do
    live = Enum.filter(rows, &(&1.kind == :enterprise))

    price_points =
      live
      |> Enum.group_by(fn row ->
        {row.currency, row.interval, row.amount |> amount_or_nil() |> format()}
      end)
      |> Enum.map(fn {{currency, interval, amount}, group} ->
        %{currency: currency, interval: interval, amount: amount, subscriptions: length(group)}
      end)
      |> Enum.sort_by(&{-&1.subscriptions, &1.currency, &1.amount})

    %{
      live_subscriptions: length(live),
      distinct_plan_ids: live |> Enum.map(& &1.plan_id) |> Enum.uniq() |> length(),
      by_interval:
        live
        |> Enum.frequencies_by(& &1.interval)
        |> Enum.map(fn {interval, n} -> %{interval: interval, subscriptions: n} end)
        |> Enum.sort_by(&{-&1.subscriptions, &1.interval}),
      distinct_price_points: length(price_points),
      top_price_points: Enum.take(price_points, 15),
      plan_ids_shared_by_several_teams: plan_ids_shared_by_several_teams(),
      teams_with_several_enterprise_plans: teams_with_several_enterprise_plans()
    }
  end

  defp subscribed_enterprise_plans() do
    from(ep in EnterprisePlan,
      join: s in Subscription,
      on: s.paddle_plan_id == ep.paddle_plan_id and s.team_id == ep.team_id,
      distinct: ep.id,
      select: ep
    )
  end

  defp plan_ids_shared_by_several_teams() do
    from(ep in Ecto.Query.subquery(subscribed_enterprise_plans()),
      group_by: ep.paddle_plan_id,
      having: count(ep.team_id, :distinct) > 1,
      select: ep.paddle_plan_id
    )
    |> Repo.all()
    |> length()
  end

  defp teams_with_several_enterprise_plans() do
    from(ep in Ecto.Query.subquery(subscribed_enterprise_plans()),
      group_by: ep.team_id,
      having: count(ep.id) > 1,
      select: ep.team_id
    )
    |> Repo.all()
    |> length()
  end

  defp read_list_prices() do
    path = Application.app_dir(:plausible, ["priv", "plan_prices.json"])

    with {:ok, content} <- File.read(path),
         {:ok, prices} when is_map(prices) <- Jason.decode(content) do
      prices
    else
      _ -> %{}
    end
  end

  defp parse_amount(nil), do: :error

  defp parse_amount(string) when is_binary(string) do
    case Decimal.parse(String.trim(string)) do
      {amount, ""} -> {:ok, amount}
      _ -> :error
    end
  end

  defp amount_or_nil({:ok, amount}), do: amount
  defp amount_or_nil(:error), do: nil

  defp to_decimal(number) when is_float(number), do: Decimal.from_float(number)
  defp to_decimal(number), do: Decimal.new(number)

  defp format(nil), do: nil
  defp format(decimal), do: decimal |> Decimal.round(2) |> Decimal.to_string(:normal)
end
