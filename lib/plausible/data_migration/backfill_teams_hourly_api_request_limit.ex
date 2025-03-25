defmodule Plausible.DataMigration.BackfillTeamsHourlyRequestLimit do
  @moduledoc """
  !!!WARNING!!!: This script is used in migrations. Please take special care
  when altering it.

  Backfill `Team.hourly_api_request_limit`.
  """

  import Ecto.Query

  alias Plausible.Billing
  alias Plausible.Repo
  alias Plausible.Teams

  def run(opts \\ []) do
    dry_run? = Keyword.get(opts, :dry_run?, true)

    log("DRY RUN: #{dry_run?}")

    active_enterprise_plans_query =
      from t in Teams.Team,
        as: :team,
        inner_lateral_join: s in subquery(Teams.last_subscription_join_query()),
        on: true,
        inner_join: ep in Billing.EnterprisePlan,
        on: ep.team_id == t.id and ep.paddle_plan_id == s.paddle_plan_id,
        select: ep

    active_enterprise_plans_query
    |> Repo.all()
    |> tap(fn enterprise_plans ->
      log("About to update #{length(enterprise_plans)} teams with active enterprise plans...")
    end)
    |> Enum.each(fn enterprise_plan ->
      log(
        "Updating team ##{enterprise_plan.team_id} to hourly API request limit " <>
          "of #{enterprise_plan.hourly_api_request_limit} rps"
      )

      if not dry_run? do
        Repo.update_all(
          from(t in Teams.Team, where: t.id == ^enterprise_plan.team_id),
          set: [hourly_api_request_limit: enterprise_plan.hourly_api_request_limit]
        )
      end
    end)

    log("Done!")
  end

  def log(msg) do
    IO.puts("[#{inspect(__MODULE__)}] #{msg}")
  end
end
