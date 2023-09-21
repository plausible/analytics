defmodule Plausible.DataMigration.RewriteFunnelDupes do
  @moduledoc """
  A data fix migration that seeks funnels having steps
  whose goals are equally named.
  It then tries to rewrite the duplicate goals using the
  oldest goal available. In extreme cases, e.g. when multiple
  duplicates are found for a single funnel, it will either
  reduce or completely remove the funnel.
  This enables us to run a migration later on that will
  delete duplicate goals and enforce goal uniqueness at the
  database level via a CHECK constraint.

  To run, just call the `run` function.
  """
  use Plausible.DataMigration, dir: "FunnelDupeGoals", repo: Plausible.Repo
  import Ecto.Query

  def run(_ \\ []) do
    {:ok, %{rows: rows}} = run_sql("list-funnels-with-dupe-goal-ids")
    data = Enum.map(rows, &to_map/1)

    by_site_id = Enum.group_by(data, & &1.site_id)

    Enum.into(by_site_id, %{}, fn {site_id, data} ->
      site_meta =
        %{}
        |> Map.put(:domain, List.first(data).domain)
        |> Map.put(:site_id, site_id)
        |> Map.put(
          :changes,
          Enum.map(
            data,
            fn d ->
              %{
                site_id: site_id,
                og_goal_id: d.goal_id,
                goal_name: d.goal_name,
                funnel_name: d.funnel_name,
                funnel_id: d.funnel_id,
                funnel_step_id: d.funnel_step_id,
                to: Enum.min(d.dupe_goal_ids),
                og_steps_count: length(d.all_goal_ids)
              }
            end
          )
          |> Enum.group_by(& &1.funnel_id)
        )

      {site_id, site_meta}
    end)
    |> translate_to_db_ops()
    |> execute()
  end

  def execute(data) do
    Plausible.Repo.transaction(fn ->
      for {site_id, meta} <- data do
        IO.puts("\n\nProcessing site ID: #{site_id} (#{meta.domain}):")

        for {funnel_id, changes} <- meta.changes do
          IO.puts(
            "\nProcessing changes for funnel ID: #{funnel_id} - '#{Enum.at(changes, 0).funnel_name}'"
          )

          Enum.each(changes, fn change ->
            apply_change(funnel_id, change)
          end)
        end

        IO.puts("\nFinished processing site ID: #{site_id} (#{meta.domain}).")
      end
    end)
  end

  def apply_change(funnel_id, %{update_type: :delete_whole_funnel} = change) do
    IO.puts(
      "Deleting whole funnel '#{change.funnel_name}', there is no way to make it functional without duplicates"
    )

    Plausible.Repo.delete_all(
      from(f in Plausible.Funnel,
        where: f.site_id == ^change.site_id,
        where: f.id == ^funnel_id
      )
    )
  end

  def apply_change(funnel_id, %{update_type: :delete_step} = change) do
    IO.puts(
      "Deleting step ID:#{change.funnel_step_id} '#{change.goal_name}' - otherwise there will be duplicates in the funnel."
    )

    step =
      Plausible.Repo.get_by!(Plausible.Funnel.Step,
        funnel_id: funnel_id,
        id: change.funnel_step_id
      )

    {:ok, _} = Plausible.Repo.delete(step)
  end

  def apply_change(
        _funnel_id,
        %{update_type: :update_step, og_goal_id: goal_id, to: goal_id} = change
      ) do
    IO.puts(
      "Doing nothing for step '#{change.goal_name}' - the duplicate goal exists, but the update is no-op"
    )

    :ok
  end

  def apply_change(funnel_id, %{update_type: :update_step} = change) do
    IO.puts(
      "Updating step '#{change.goal_name}' from goal_id:#{change.og_goal_id} to goal_id:#{change.to}"
    )

    step =
      Plausible.Repo.get_by!(Plausible.Funnel.Step,
        funnel_id: funnel_id,
        id: change.funnel_step_id
      )

    change = Ecto.Changeset.change(step, goal_id: change.to)
    {:ok, _} = Plausible.Repo.update(change)
  end

  def translate_to_db_ops(data) do
    for {site, meta} <- data do
      {site, to_db_ops(meta)}
    end
  end

  def to_db_ops(meta) do
    new_changes =
      for {funnel_id, changes} <- meta.changes do
        safe_step_updates = changes |> Enum.uniq_by(& &1.to)

        steps_to_delete = changes -- safe_step_updates

        safe_step_updates =
          safe_step_updates
          |> Enum.map(&Map.put(&1, :update_type, :update_step))

        changes =
          Enum.map(steps_to_delete, &Map.put(&1, :update_type, :delete_step)) ++ safe_step_updates

        og_steps_count = Enum.at(changes, 0).og_steps_count

        steps_after_changes = og_steps_count - Enum.count(steps_to_delete)

        if steps_after_changes >= 2 do
          {funnel_id, changes}
        else
          {funnel_id,
           [
             Enum.at(changes, 0)
             |> Map.put(:update_type, :delete_whole_funnel)
           ]}
        end
      end

    Map.put(meta, :changes, new_changes)
  end

  def to_map(row) do
    [
      domain,
      site_id,
      funnel_name,
      funnel_id,
      funnel_step_id,
      goal_id,
      goal_name,
      dupe_goal_ids,
      all_goal_ids
    ] = row

    %{
      domain: domain,
      site_id: site_id,
      funnel_name: funnel_name,
      funnel_id: funnel_id,
      funnel_step_id: funnel_step_id,
      goal_id: goal_id,
      goal_name: goal_name,
      dupe_goal_ids: dupe_goal_ids,
      all_goal_ids: all_goal_ids
    }
  end
end
