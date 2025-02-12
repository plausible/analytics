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
    h30_ago = DateTime.shift(DateTime.utc_now(), hour: -48)

    {:ok, _} = Salts.start_link(name: __MODULE__, now: h30_ago)

    h24_ago = DateTime.shift(DateTime.utc_now(), hour: -24)

    :ok = Salts.rotate(__MODULE__, h24_ago)

    %{current: old_current, previous: _old_previous} =
      Salts.fetch(__MODULE__)

    q = from(s in "salts")
    count = Repo.aggregate(q, :count)
    assert count == 2

    future = DateTime.shift(DateTime.utc_now(), hour: 24)

    :ok = Salts.rotate(__MODULE__, future)

    %{current: _current, previous: ^old_current} =
      Salts.fetch(__MODULE__)

    q = from(s in "salts")
    count = Repo.aggregate(q, :count)
    assert count == 2
  end
end
