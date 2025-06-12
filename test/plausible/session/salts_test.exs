defmodule Plausible.Session.SaltsTest do
  use Plausible.DataCase, async: false

  alias Plausible.Session.Salts
  import Ecto.Query

  test "agent starts and responds with current salt" do
    {:ok, _} = Salts.start_link(name: __MODULE__)
    %{current: current, previous: nil} = Salts.fetch(__MODULE__)
    assert is_binary(current)
  end

  test "agent starts and responds with current and previous salt after rotation" do
    {:ok, _} = Salts.start_link(name: __MODULE__)
    %{current: first, previous: nil} = Salts.fetch(__MODULE__)
    :ok = Salts.rotate(__MODULE__)

    %{current: current, previous: ^first} = Salts.fetch(__MODULE__)
    assert is_binary(current)
  end

  test "old salts can be cleaned" do
    t1 = ~U[2025-06-10 15:29:40Z]

    {:ok, _} = Salts.start_link(name: __MODULE__, now: t1)

    t2 = ~U[2025-06-11 15:29:40Z]

    :ok = Salts.rotate(__MODULE__, t2)

    %{current: old_current, previous: _old_previous} =
      Salts.fetch(__MODULE__)

    q = from(s in "salts")
    count = Repo.aggregate(q, :count)
    assert count == 2

    t3 = ~U[2025-06-13 15:34:40Z]

    :ok = Salts.rotate(__MODULE__, t3)

    %{current: _current, previous: ^old_current} =
      Salts.fetch(__MODULE__)

    q = from(s in "salts")
    count = Repo.aggregate(q, :count)
    assert count == 2
  end

  test "salts refresh when another node roates them" do
    t1 = ~U[2024-06-10 15:29:40Z]
    {:ok, _} = Salts.start_link(name: :node_1, now: t1)
    {:ok, _} = Salts.start_link(name: :node_2, now: t1)

    t2 = ~U[2024-06-11 15:29:40Z]

    :ok = Salts.rotate(:node_2, t2)

    assert Salts.fetch(:node_1) != Salts.fetch(:node_2)

    send(:node_1, {:refresh, t2})

    assert eventually(fn ->
             {Salts.fetch(:node_1) == Salts.fetch(:node_2), :ok}
           end)
  end
end
