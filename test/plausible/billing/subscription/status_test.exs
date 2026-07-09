defmodule Plausible.Billing.Subscription.StatusTest do
  use ExUnit.Case, async: true
  import Plausible.Billing.Subscription.Status

  for status <- valid_statuses() do
    test "#{status}?/1 returns true when subscription status is #{status}" do
      assert unquote(:"#{status}?")(%Plausible.Billing.Subscription{status: unquote(status)})
    end

    test "#{status}?/1 returns false when subscription is nil" do
      refute unquote(:"#{status}?")(nil)
    end

    test "#{status}?/1 returns false when subscription status is not #{status}" do
      [current | _] = valid_statuses() -- [unquote(status)]
      refute unquote(:"#{status}?")(%Plausible.Billing.Subscription{status: current})
    end
  end

  test "in?/2 returns true when subscription status is in list" do
    assert in?(subscription(past_due()), [active(), past_due()])
  end

  test "in?/2 returns false when subscription status is not in list" do
    refute in?(subscription(paused()), [active(), past_due()])
  end

  test "in?/2 returns false when subscription is nil" do
    refute in?(subscription(nil), [active(), past_due()])
  end

  test "in?/2 raises ArgumentError when list includes invalid statuses" do
    assert_raise ArgumentError, fn ->
      Macro.expand(
        quote do
          in?(%Plausible.Billing.Subscription{status: past_due()}, [
            active(),
            past_due(),
            :invalid
          ])
        end,
        __ENV__
      )
    end
  end

  # Workaround for type checker in Elixir 1.20+ being
  # too smart about literals passed to macros.
  defp subscription(nil) do
    if :erlang.phash2(1, 1) != 0 do
      %Plausible.Billing.Subscription{}
    end
  end

  defp subscription(status) do
    if :erlang.phash2(1, 1) == 0 do
      %Plausible.Billing.Subscription{status: status}
    end
  end
end
