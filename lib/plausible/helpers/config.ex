defmodule Plausible.ConfigHelpers do
  def get_var_from_path_or_env(config_dir, var_name, default \\ nil) do
    var_path = Path.join(config_dir, var_name)

    if File.exists?(var_path) do
      File.read!(var_path) |> String.trim()
    else
      System.get_env(var_name, default)
    end
  end

  def get_int_from_path_or_env(config_dir, var_name, default \\ nil) do
    var = get_var_from_path_or_env(config_dir, var_name)

    case var do
      nil ->
        default

      var ->
        case Integer.parse(var) do
          {int, ""} -> int
          _ -> raise "Config variable #{var_name} must be an integer. Got #{var}"
        end
    end
  end

  @doc """
  Similar to `Enum.zip/2` and `List.flatten/1` but doesn't truncate any of the lists.

  Examples:

      iex> join_intersperse([], [])
      []

      iex> join_intersperse([1], [])
      [1]

      iex> join_intersperse([], [2])
      [2]

      iex> join_intersperse([1], [2])
      [1, 2]

      iex> join_intersperse([1], [2, 3])
      [1, 2, 3]

      iex> join_intersperse([1, 3], [2])
      [1, 2, 3]

      iex> join_intersperse([1], [2, 3, 4])
      [1, 2, 3, 4]

      iex> join_intersperse([1, 3, 4], [2])
      [1, 2, 3, 4]

      iex> ipv4 = ["142.251.175.139", "142.251.175.100", "142.251.175.138", "142.251.175.113", "142.251.175.102", "142.251.175.101"]
      iex> ipv6 = ["2404:6800:4003:c1c::66", "2404:6800:4003:c1c::8a", "2404:6800:4003:c1c::64", "2404:6800:4003:c1c::71"]
      iex> join_intersperse(ipv6, ipv4)
      [
        "2404:6800:4003:c1c::66",
        "142.251.175.139",
        "2404:6800:4003:c1c::8a",
        "142.251.175.100",
        "2404:6800:4003:c1c::64",
        "142.251.175.138",
        "2404:6800:4003:c1c::71",
        "142.251.175.113",
        "142.251.175.102",
        "142.251.175.101"
      ]

  """
  def join_intersperse([], []), do: []
  def join_intersperse([], [_ | _] = right), do: right
  def join_intersperse([_ | _] = left, []), do: left

  def join_intersperse([left | rest_left], [right | rest_right]) do
    [left, right | join_intersperse(rest_left, rest_right)]
  end
end
