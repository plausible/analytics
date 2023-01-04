defmodule Plausible.ClickhouseRepo do
  use Ecto.Repo,
    otp_app: :plausible,
    adapter: ClickhouseEcto

  defmacro __using__(_) do
    quote do
      alias Plausible.ClickhouseRepo
      import Ecto
      import Ecto.Query, only: [from: 1, from: 2]
    end
  end

  @task_timeout 15_000
  def parallel_tasks(queries) do
    Enum.map(queries, &Task.async/1)
    |> Task.await_many(@task_timeout)
  end
end
