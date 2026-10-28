defmodule Plausible.Billing.MigrationAudit do
  @moduledoc """
  Read-only audit report for the Paddle Classic->Billing migration.
  Paddle is only called when explicitly asked for with `catalog: true`,
  and then with read-only requests.

  ## Answering the audit asked for in the Paddle Billing project

  | Item                                            | Where                                                                                           |
  | ----------------------------------------------- | ----------------------------------------------------------------------------------------------- |
  | Active subscriptions by plan id                 | `plan_resolution/1`, `:by_plan_id`                                                              |
  | Plan generation                                 | `plan_resolution/1`, `:by_generation`                                                           |
  | Enterprise plans attached to live subscriptions | `plan_resolution/1`, `:enterprise_plans`                                                        |
  | Active, paused, trialing, past-due              | `subscribers/1`, `:statuses`                                                                    |
  | Plans with multiple currency prices             | `classic_catalog/1`, `:plans`                                                                   |
  | Customer-specific or negotiated plans           | `subscribers/1`, `:enterprise` and `:vs_list_price`; `classic_catalog/1`, `:plans` `:by_origin` |
  | Recurring or one-time modifiers                 | `classic_catalog/1`, `:modifiers`                                                               |
  | Effective currency and amount paid              | `subscribers/1`, `:billed` and `:vs_list_price`                                                 |
  """

  use Plausible.Repo

  import Ecto.Query, only: [from: 2, dynamic: 2]

  require Plausible.Billing.Subscription.Status

  alias Plausible.Billing.{EnterprisePlan, Plans, Subscription}
  alias Plausible.Billing.MigrationAudit.{ClassicCatalog, Subscribers}
  alias Plausible.Billing.Subscription.Status

  @plan_files [
    legacy_plans: 1,
    plans_v1: 1,
    plans_v2: 2,
    plans_v3: 3,
    plans_v4: 4,
    plans_v5: 5
  ]

  @classic_id_format ~r/^\d+$/

  @type category ::
          :free
          | :manual
          | :enterprise
          | :unresolved
          | {:regular, generation :: integer(), kind :: atom()}

  @type problem :: %{check: atom(), file: String.t() | nil, message: String.t()}

  @doc """
  bin/plausible rpc "IO.puts(Plausible.Billing.MigrationAudit.json_report())"

    or, from a remote shell:

  iex> IO.puts(Plausible.Billing.MigrationAudit.json_report())
  """
  @spec json_report(Keyword.t()) :: String.t()
  def json_report(opts \\ []) do
    opts
    |> Keyword.put_new(:catalog, true)
    |> collect()
    |> update_in([:plan_resolution, :unresolved], fn rows ->
      %{count: length(rows), rows: "left out, see plan_resolution/1"}
    end)
    |> to_json()
  end

  @spec collect(Keyword.t()) :: map()
  def collect(opts \\ []) do
    result = %{
      plan_resolution: plan_resolution(opts),
      plan_files: plan_files_integrity(opts),
      subscribers: subscribers(opts)
    }

    if Keyword.get(opts, :catalog, false) do
      Map.put(result, :classic_catalog, classic_catalog_result(opts))
    else
      result
    end
  end

  defp classic_catalog_result(opts) do
    case classic_catalog(opts) do
      {:ok, catalog} ->
        catalog

      {:error, {part, reason}} ->
        %{error: %{failed_call: part, reason: inspect(reason)}}
    end
  end

  @doc """
  Like `collect/1`, but prints a readable report, and returns the same data.
  """
  def run(opts \\ []) do
    result = collect(opts)

    print_plan_resolution(result.plan_resolution)
    print_plan_files(result.plan_files)
    print_subscribers(result.subscribers)

    case Map.fetch(result, :classic_catalog) do
      {:ok, catalog} ->
        print_classic_catalog(catalog)

      :error ->
        log("Classic catalog and modifiers skipped. Run with `catalog: true` to include them.")
    end

    result
  end

  @doc """
  Subscribers by status, effective amounts and enterprise plans. Database only,
  see `Plausible.Billing.MigrationAudit.Subscribers.audit/1` for the result and options.
  """
  defdelegate subscribers(opts \\ []), to: Subscribers, as: :audit

  @doc """
  Plan catalog and modifiers from Paddle Classic. Makes read-only API calls, see
  `Plausible.Billing.MigrationAudit.ClassicCatalog.audit/1` for the result and options.
  """
  defdelegate classic_catalog(opts \\ []), to: ClassicCatalog, as: :audit

  @doc """
  Encodes a result of this module as pretty JSON.
  """
  @spec to_json(term()) :: String.t()
  def to_json(result), do: Jason.encode!(result, pretty: true)

  # --- plan resolution ----------------------------------------------------------

  @doc """
  Resolves subscriptions to plans exactly like the app does
  (`Plausible.Billing.Plans.get_subscription_plan/1`) and summarises the result.

  Options:

    * `:scope` - `:live` (default) audits every subscription that could matter
      for a port: active, past due or paused, plus cancelled ones that are still
      inside the paid period. `:current` audits the last subscription of every
      team, which is the one the app uses to determine a team's plan.
    * `:today` - the date used for "still inside the paid period" (default:
      today, UTC).
  """
  @spec plan_resolution(Keyword.t()) :: map()
  def plan_resolution(opts \\ []) do
    scope = Keyword.get(opts, :scope, :live)
    today = Keyword.get(opts, :today, Date.utc_today())

    subscriptions = Repo.all(subscriptions_query(scope, today))
    classified = Enum.map(subscriptions, &{&1, classify(&1)})

    %{
      scope: scope,
      today: today,
      total: length(subscriptions),
      by_category: count_by(classified, fn {_s, category} -> category_label(category) end),
      by_plan_id: by_plan_id(classified),
      by_generation: by_generation(classified),
      unresolved:
        for {subscription, :unresolved} <- classified do
          %{
            subscription_id: subscription.id,
            team_id: subscription.team_id,
            paddle_plan_id: subscription.paddle_plan_id,
            status: subscription.status,
            next_bill_date: subscription.next_bill_date
          }
        end,
      teams_with_multiple_subscriptions: teams_with_multiple_subscriptions(today),
      enterprise_plans: enterprise_plans_summary(today)
    }
  end

  @doc """
  Classifies the plan of a single subscription.
  """
  @spec classify(Subscription.t()) :: category()
  def classify(%Subscription{} = subscription) do
    if Subscription.manual_subscription?(subscription) do
      :manual
    else
      case Plans.get_subscription_plan(subscription) do
        nil -> :unresolved
        :free_10k -> :free
        %EnterprisePlan{} -> :enterprise
        %{generation: generation, kind: kind} -> {:regular, generation, kind}
      end
    end
  end

  defp subscriptions_query(:live, today) do
    from(s in Subscription, where: ^live_condition(today), order_by: [asc: s.id])
  end

  defp subscriptions_query(:current, _today) do
    # one row per team: the last subscription, as in Teams.last_subscription_query/0
    from(s in Subscription,
      distinct: s.team_id,
      order_by: [asc: s.team_id, desc: s.inserted_at, desc: s.id]
    )
  end

  defp live_condition(today) do
    live = [Status.active(), Status.past_due(), Status.paused()]

    dynamic(
      [s],
      s.status in ^live or (s.status == ^Status.deleted() and s.next_bill_date >= ^today)
    )
  end

  defp count_by(items, fun) do
    items
    |> Enum.frequencies_by(fun)
    |> Enum.map(fn {category, n} -> %{category: category, subscriptions: n} end)
    |> Enum.sort_by(&{-&1.subscriptions, &1.category})
  end

  defp category_label({:regular, generation, kind}), do: "v#{generation} #{kind}"
  defp category_label(other), do: Atom.to_string(other)

  defp by_plan_id(classified) do
    classified
    |> Enum.group_by(fn {s, category} -> {s.paddle_plan_id, category_label(category)} end)
    |> Enum.map(fn {{plan_id, label}, items} ->
      %{paddle_plan_id: plan_id, category: label, subscriptions: length(items)}
    end)
    |> Enum.sort_by(&{-&1.subscriptions, &1.paddle_plan_id})
  end

  # For every generation of the static plans: how many live subscriptions and
  # distinct plan ids are in use, against how many plan ids the files contain.
  # This is the list of Billing prices that are actually needed per generation.
  defp by_generation(classified) do
    in_use =
      for {s, {:regular, generation, _kind}} <- classified, do: {generation, s.paddle_plan_id}

    ids_in_files =
      Plans.all()
      |> Enum.flat_map(fn plan ->
        for id <- [plan.monthly_product_id, plan.yearly_product_id],
            is_binary(id),
            do: {plan.generation, id}
      end)

    for generation <- ids_in_files |> Enum.map(&elem(&1, 0)) |> Enum.uniq() |> Enum.sort() do
      used = for {^generation, id} <- in_use, do: id

      %{
        generation: generation,
        subscriptions: length(used),
        distinct_plan_ids_in_use: used |> Enum.uniq() |> length(),
        plan_ids_in_files: for({^generation, _} <- ids_in_files, do: 1) |> length()
      }
    end
  end

  defp teams_with_multiple_subscriptions(today) do
    all =
      from(s in Subscription, group_by: s.team_id, having: count(s.id) > 1, select: s.team_id)

    live =
      from(s in Subscription,
        where: ^live_condition(today),
        group_by: s.team_id,
        having: count(s.id) > 1,
        select: s.team_id
      )

    %{any_status: length(Repo.all(all)), live: length(Repo.all(live))}
  end

  defp enterprise_plans_summary(today) do
    attached = fn condition ->
      from(ep in EnterprisePlan,
        as: :ep,
        where:
          exists(
            from(s in Subscription,
              where: s.team_id == parent_as(:ep).team_id,
              where: s.paddle_plan_id == parent_as(:ep).paddle_plan_id,
              where: ^condition
            )
          ),
        select: count(ep.id)
      )
      |> Repo.one()
    end

    %{
      total: Repo.aggregate(EnterprisePlan, :count),
      attached_to_live_subscription: attached.(live_condition(today)),
      attached_to_any_subscription: attached.(dynamic([s], true))
    }
  end

  @doc """
  Checks the static plan files and returns a list of problems (empty if all is
  well). Reads the files from the release's `priv` directory.

  Options:

    * `:priv_dir` - directory to read from (default: the app's `priv`).
  """
  @spec plan_files_integrity(Keyword.t()) :: [problem()]
  def plan_files_integrity(opts \\ []) do
    priv_dir = Keyword.get(opts, :priv_dir, Application.app_dir(:plausible, "priv"))

    files =
      for {name, _generation} <- @plan_files, into: %{} do
        file = Atom.to_string(name)
        {file, priv_dir |> Path.join("#{file}.json") |> read_json()}
      end

    prices = priv_dir |> Path.join("plan_prices.json") |> read_json()

    check_plan_files(files, prices)
  end

  defp read_json(path) do
    with {:ok, content} <- File.read(path),
         {:ok, decoded} <- Jason.decode(content) do
      decoded
    else
      {:error, %Jason.DecodeError{} = error} ->
        {:error, "#{Path.basename(path)}: invalid JSON (#{Exception.message(error)})"}

      {:error, reason} ->
        {:error, "#{Path.basename(path)}: #{:file.format_error(reason)}"}
    end
  end

  @doc """
  Pure part of `plan_files_integrity/1`, for testing and for use on data that
  isn't on disk.

  `files` maps a file name without extension (for example `"plans_v1"`) to its
  decoded JSON (a list of plan maps), `prices` is
  the decoded `plan_prices.json` (plan id => price). A value of
  `{:error, message}` stands for a file that couldn't be read.

  Checks:

    * `:unreadable` - a file is missing or isn't valid
    * `:generation_mismatch` - a plan's `generation` doesn't match its file
    * `:bad_id_format` - an id isn't a numeric (Paddle Classic) id
    * `:same_monthly_and_yearly_id` - a plan uses one id for both intervals
    * `:duplicate_id` - an id is used more than once
    * `:duplicate_plan` - two plans in a file share kind and pageview limit
    * `:missing_price` / `:orphan_price` / `:bad_price` - `plan_prices.json` has
      to hold a positive price for every plan id, and nothing else
  """
  @spec check_plan_files(map(), map() | {:error, String.t()}) :: [problem()]
  def check_plan_files(files, prices) do
    {readable, unreadable} =
      Enum.split_with(files, fn {_name, content} -> is_list(content) end)

    readable = Map.new(readable)

    unreadable_problems =
      for {name, {:error, message}} <- unreadable do
        problem(:unreadable, name, message)
      end

    prices_problems =
      case prices do
        {:error, message} -> [problem(:unreadable, "plan_prices.json", message)]
        prices when is_map(prices) -> check_prices(readable, prices)
      end

    unreadable_problems ++
      Enum.flat_map(readable, fn {name, plans} -> check_file(name, plans) end) ++
      check_duplicate_ids(readable) ++
      prices_problems
  end

  defp problem(check, file, message), do: %{check: check, file: file, message: message}

  defp file_generation(name) do
    Keyword.fetch!(@plan_files, String.to_existing_atom(name))
  end

  defp plan_ids(plan) do
    for key <- ["monthly_product_id", "yearly_product_id"],
        id = plan[key],
        not is_nil(id),
        do: {key, id}
  end

  defp check_file(name, plans) do
    generation = file_generation(name)

    per_plan =
      plans
      |> Enum.with_index(1)
      |> Enum.flat_map(fn {plan, index} ->
        label = "#{name} ##{index} (#{plan["kind"]}, #{plan["monthly_pageview_limit"]})"

        generation_problems =
          if plan["generation"] != generation do
            [
              problem(
                :generation_mismatch,
                name,
                "#{label}: generation is #{inspect(plan["generation"])}, expected #{generation}"
              )
            ]
          else
            []
          end

        id_problems =
          for {key, id} <- plan_ids(plan),
              not (is_binary(id) and Regex.match?(@classic_id_format, id)) do
            problem(:bad_id_format, name, "#{label}: #{key} #{inspect(id)} isn't a numeric id")
          end

        same_id_problems =
          case plan_ids(plan) do
            [{_, id}, {_, id}] ->
              [
                problem(
                  :same_monthly_and_yearly_id,
                  name,
                  "#{label}: monthly and yearly both use #{inspect(id)}"
                )
              ]

            _ ->
              []
          end

        generation_problems ++ id_problems ++ same_id_problems
      end)

    duplicate_plans =
      plans
      |> Enum.frequencies_by(&{&1["kind"], &1["monthly_pageview_limit"]})
      |> Enum.filter(fn {_key, count} -> count > 1 end)
      |> Enum.map(fn {{kind, limit}, count} ->
        problem(
          :duplicate_plan,
          name,
          "#{count} plans with kind #{inspect(kind)} and limit #{inspect(limit)}"
        )
      end)

    per_plan ++ duplicate_plans
  end

  defp check_duplicate_ids(files) do
    for {id, owners} <- ids_with_owners(files), length(owners) > 1 do
      problem(
        :duplicate_id,
        nil,
        "#{inspect(id)} is used #{length(owners)} times (#{Enum.join(owners, ", ")})"
      )
    end
  end

  defp ids_with_owners(files) do
    files
    |> Enum.flat_map(fn {name, plans} ->
      for plan <- plans, {key, id} <- plan_ids(plan), do: {id, "#{name} #{key}"}
    end)
    |> Enum.group_by(&elem(&1, 0), &elem(&1, 1))
  end

  defp check_prices(files, prices) do
    known_ids =
      for {_name, plans} <- files,
          plan <- plans,
          {_key, id} <- plan_ids(plan),
          into: MapSet.new(),
          do: id

    missing =
      for id <- known_ids, not Map.has_key?(prices, id) do
        problem(:missing_price, "plan_prices.json", "no price for plan id #{inspect(id)}")
      end

    orphans =
      for {id, _price} <- prices, not MapSet.member?(known_ids, id) do
        problem(:orphan_price, "plan_prices.json", "price for unknown plan id #{inspect(id)}")
      end

    bad =
      for {id, price} <- prices, not (is_number(price) and price > 0) do
        problem(
          :bad_price,
          "plan_prices.json",
          "price for #{inspect(id)} is #{inspect(price)}, expected a positive number"
        )
      end

    Enum.sort_by(missing ++ orphans ++ bad, & &1.message)
  end

  # --- printing ------------------------------------------------------------------------

  defp print_plan_resolution(result) do
    log("Subscription plan resolution (scope: #{result.scope}, as of #{result.today})")
    log("  subscriptions audited: #{result.total}")

    log("  by category:")
    for row <- result.by_category, do: log("    #{pad(row.category, 22)} #{row.subscriptions}")

    log("  by generation (regular plans only):")

    for g <- result.by_generation do
      log(
        "    v#{g.generation}: #{g.subscriptions} subscriptions on " <>
          "#{g.distinct_plan_ids_in_use} of #{g.plan_ids_in_files} plan ids"
      )
    end

    log("  by plan id (top 15):")

    for row <- Enum.take(result.by_plan_id, 15) do
      log("    #{pad(row.paddle_plan_id, 22)} #{pad(row.category, 16)} #{row.subscriptions}")
    end

    multiple = result.teams_with_multiple_subscriptions

    log(
      "  teams with more than one subscription row: #{multiple.any_status} " <>
        "(#{multiple.live} with more than one live row)"
    )

    enterprise = result.enterprise_plans

    log(
      "  enterprise plans: #{enterprise.total} total, " <>
        "#{enterprise.attached_to_live_subscription} attached to a live subscription, " <>
        "#{enterprise.attached_to_any_subscription} attached to any subscription"
    )

    case result.unresolved do
      [] ->
        log("  unresolved subscriptions: none")

      unresolved ->
        log("  UNRESOLVED subscriptions (#{length(unresolved)}), these lose their plan limits:")

        for row <- unresolved do
          log(
            "    subscription ##{row.subscription_id} team ##{row.team_id} " <>
              "plan #{inspect(row.paddle_plan_id)} #{row.status} next_bill_date=#{row.next_bill_date}"
          )
        end
    end
  end

  defp print_plan_files([]), do: log("Plan files: no problems found")

  defp print_plan_files(problems) do
    log("Plan files: #{length(problems)} problem(s)")

    for p <- problems do
      log("  [#{p.check}] #{p.file || "-"}: #{p.message}")
    end
  end

  defp print_subscribers(result) do
    log("Subscribers (as of #{result.as_of})")
    statuses = result.statuses
    log("  current subscription of #{statuses.teams_with_subscription} teams, by status:")
    for row <- statuses.by_status, do: log("    #{pad(row.status, 22)} #{row.teams}")
    log("  teams in the app's own trial without a subscription: #{statuses.teams_on_app_trial}")

    log("  paid by live subscribers (kind, currency, interval):")

    for row <- result.billed do
      log(
        "    #{pad(row.kind, 11)} #{pad(row.currency, 4)} #{pad(row.interval, 8)} " <>
          "#{pad(row.subscriptions, 7)} total #{row.total} (min #{row.min}, max #{row.max})" <>
          if(row.unparsable_amounts > 0,
            do: ", #{row.unparsable_amounts} unparsable",
            else: ""
          )
      )
    end

    log("  regular plans, amount paid vs the USD list price:")

    for row <- result.vs_list_price.by_currency do
      log(
        "    #{pad(row.currency, 4)} #{row.subscriptions} subscriptions: #{row.equal} equal, " <>
          "#{row.lower} lower, #{row.higher} higher, #{row.no_list_price} without list price, " <>
          "#{row.unparsable} unparsable"
      )
    end

    log("  most common off-list price points (top 10):")

    for row <- Enum.take(result.vs_list_price.off_list_price_points, 10) do
      log(
        "    plan #{pad(row.plan_id, 8)} #{row.currency} #{pad(row.interval, 8)} paid #{row.paid} " <>
          "vs list #{row.list_price}: #{row.subscriptions}"
      )
    end

    enterprise = result.enterprise

    log(
      "  enterprise: #{enterprise.live_subscriptions} live subscriptions on " <>
        "#{enterprise.distinct_plan_ids} plan ids, #{enterprise.distinct_price_points} distinct price points"
    )

    log(
      "    plan ids shared by several teams: #{enterprise.plan_ids_shared_by_several_teams}, " <>
        "teams with several enterprise plans: #{enterprise.teams_with_several_enterprise_plans}"
    )

    log("    top price points:")

    for row <- Enum.take(enterprise.top_price_points, 10) do
      log(
        "      #{row.currency} #{pad(row.interval, 8)} #{pad(row.amount, 10)} #{row.subscriptions}"
      )
    end
  end

  defp print_classic_catalog(%{error: %{failed_call: part, reason: reason}}) do
    log("Classic catalog: failed to fetch #{part}: #{reason}")
  end

  defp print_classic_catalog(%{plans: plans, modifiers: modifiers}) do
    log("Classic catalog: #{plans.total} plans")
    log("  by origin: #{inspect(plans.by_origin)}")

    log(
      "  with a live subscription, by origin: #{inspect(plans.with_live_subscription_by_origin)}"
    )

    log(
      "  single currency: #{plans.single_currency}, multiple currencies: #{plans.multi_currency} " <>
        "(#{plans.multi_currency_parity} at parity, #{plans.multi_currency_differing} differing)"
    )

    log("  multiple currencies by origin: #{inspect(plans.multi_currency_by_origin)}")

    log("  without a recurring price: #{plans.without_recurring_price}")

    for row <- plans.currency_sets do
      log("    currencies #{Enum.join(row.currencies, ",")}: #{row.plans} plans")
    end

    case plans.live_plan_ids_missing_from_catalog do
      [] -> log("  every live plan id is in the catalog")
      ids -> log("  live plan ids missing from the catalog: #{Enum.join(ids, ", ")}")
    end

    log(
      "Modifiers: #{modifiers.total} (#{modifiers.recurring} recurring, #{modifiers.one_time} one-time, " <>
        "#{modifiers.recurrence_unknown} unknown) on #{modifiers.subscriptions_with_modifiers} subscriptions, " <>
        "#{modifiers.of_which_live} live"
    )

    log("  discounts: #{modifiers.discounts}, surcharges: #{modifiers.surcharges}")
    log("  #{modifiers.not_covered}")
  end

  defp pad(value, width), do: value |> to_string() |> String.pad_trailing(width)

  defp log(message), do: IO.puts("[#{inspect(__MODULE__)}] #{message}")
end
