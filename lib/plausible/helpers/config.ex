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

  def get_bool_from_path_or_env(config_dir, var_name, default \\ nil) do
    case get_var_from_path_or_env(config_dir, var_name) do
      nil -> default
      var -> parse_bool(var)
    end
  end

  @var_true ["1", "t", "true", "y", "yes", "on"]
  @var_false ["0", "f", "false", "n", "no", "off"]
  @var_bool_message Enum.zip_with(@var_true, @var_false, fn t, f -> [t, f] end)
                    |> List.flatten()
                    |> Enum.join(", ")

  defp parse_bool(var) do
    case String.downcase(var) do
      t when t in @var_true ->
        true

      f when f in @var_false ->
        false

      _ ->
        raise ArgumentError,
              "Invalid boolean value: #{inspect(var)}. Expected one of: " <> @var_bool_message
    end
  end
end
