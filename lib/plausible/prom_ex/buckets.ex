defmodule Plausible.PromEx.Buckets do
  @moduledoc """
  Adapts `Peep` for `PromEx`.

  Based on `Peep.Buckets.Custom` and `TelemetryMetricsPrometheus.Core`.
  """

  @behaviour Peep.Buckets

  @impl true
  def config(%Telemetry.Metrics.Distribution{reporter_options: reporter_options}) do
    # PromEx configures buckets with `:reporter_options`
    buckets = Keyword.fetch!(reporter_options, :buckets)

    if Enum.empty?(buckets) do
      raise ArgumentError, "expected buckets list to be non-empty, got #{inspect(buckets)}"
    end

    unless Enum.all?(buckets, &is_number/1) do
      raise ArgumentError,
            "expected buckets list to contain only numbers, got #{inspect(buckets)}"
    end

    unless buckets == Enum.uniq(Enum.sort(buckets)) do
      raise ArgumentError, "expected buckets to be ordered ascending, got #{inspect(buckets)}"
    end

    number_of_buckets = length(buckets)

    int_buckets = int_buckets(buckets, nil, 0)

    int_tree = :gb_trees.from_orddict(int_buckets)

    float_buckets =
      buckets
      |> Enum.map(&(&1 * 1.0))
      |> Enum.with_index()

    float_tree = :gb_trees.from_orddict(float_buckets)

    upper_bound =
      buckets
      |> Enum.with_index()
      |> Map.new(fn {boundary, bucket_idx} -> {bucket_idx, to_string(boundary * 1.0)} end)

    %{
      number_of_buckets: number_of_buckets,
      int_tree: int_tree,
      float_tree: float_tree,
      upper_bound: upper_bound
    }
  end

  @impl true
  def number_of_buckets(config) do
    config.number_of_buckets
  end

  @impl true
  def bucket_for(number, config) when is_integer(number) do
    elem(:gb_trees.larger(number, config.int_tree), 1)
  end

  def bucket_for(number, config) when is_float(number) do
    elem(:gb_trees.larger(number, config.float_tree), 1)
  end

  @impl true
  def upper_bound(bucket_idx, config) do
    Map.get(config.upper_bound, bucket_idx, "+Inf")
  end

  defp int_buckets([], _prev, _counter) do
    []
  end

  defp int_buckets([curr | tail], prev, counter) do
    case ceil(curr) do
      ^prev -> int_buckets(tail, prev, counter + 1)
      curr -> [{curr, counter} | int_buckets(tail, curr, counter + 1)]
    end
  end
end
