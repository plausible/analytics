defmodule Plausible.Session.WriteBuffer do
  def child_spec(opts) do
    opts = Keyword.merge([name: __MODULE__, schema: Plausible.ClickhouseSessionV2], opts)
    Plausible.Ingestion.WriteBuffer.child_spec(opts)
  end

  def start_link(opts) do
    opts = Keyword.merge([name: __MODULE__, schema: Plausible.ClickhouseSessionV2], opts)
    Plausible.Ingestion.WriteBuffer.start_link(opts)
  end

  @spec insert(sessions) :: sessions when sessions: [%Plausible.ClickhouseSessionV2{}]
  def insert(sessions) do
    sessions =
      Enum.map(sessions, fn %{is_bounce: is_bounce} = session ->
        is_bounce =
          case is_bounce do
            true -> 1
            false -> 0
            other -> other
          end

        %{session | is_bounce: is_bounce}
      end)

    Plausible.Ingestion.WriteBuffer.insert(
      __MODULE__,
      Plausible.ClickhouseSessionV2,
      sessions
    )
  end

  def flush do
    Plausible.Ingestion.WriteBuffer.flush(__MODULE__)
  end
end
