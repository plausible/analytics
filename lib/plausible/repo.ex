defmodule Plausible.Repo do
  use Ecto.Repo,
    otp_app: :plausible,
    adapter: Ecto.Adapters.Postgres

  use Scrivener, page_size: 24

  defmacro __using__(_) do
    quote do
      alias Plausible.Repo
      import Ecto
      import Ecto.Query, only: [from: 1, from: 2]
    end
  end

  def update_with_audit(%Ecto.Changeset{} = changeset, entry_name, params \\ %{}) do
    case update(changeset) do
      {:ok, result} ->
        entry_name
        |> Plausible.Audit.Entry.new(result, params)
        |> Plausible.Audit.Entry.include_change(changeset)
        |> Plausible.Audit.Entry.persist!()

        {:ok, result}

      other ->
        other
    end
  end

  def update_with_audit!(%Ecto.Changeset{} = changeset, entry_name, params \\ %{}) do
    result = update!(changeset)

    entry_name
    |> Plausible.Audit.Entry.new(result, params)
    |> Plausible.Audit.Entry.include_change(changeset)
    |> Plausible.Audit.Entry.persist!()

    result
  end
end
