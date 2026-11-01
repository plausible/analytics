defmodule Plausible.Workers.CleanEmailSuppressions do
  @moduledoc """
  Daily job garbage-collecting e-mail suppressions
  """

  use Oban.Worker, queue: :clean_email_suppressions
  use Plausible

  @impl Oban.Worker
  def perform(_job)

  on_ce do
    def perform(_job), do: :ok
  end

  on_ee do
    alias Plausible.EmailSuppressions

    @stale_after Duration.new!(day: -14)
    @batch_size 1_000

    def perform(_job) do
      candidates = EmailSuppressions.list_orphaned(@stale_after, @batch_size)

      confirmed =
        candidates
        |> Enum.map(& &1.email)
        |> Plausible.Postmark.delete_suppressions()
        |> MapSet.new()

      candidates
      |> Enum.filter(&MapSet.member?(confirmed, &1.email))
      |> EmailSuppressions.delete_all()

      :ok
    end
  end
end
