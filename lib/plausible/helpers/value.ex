defmodule Plausible.ValueHelpers do
  @spec validate(any(), keyword()) :: any()
  def validate(value, type: :prefixed_id) when is_binary(value) do
    prefixed_id_pattern = ~r/\A\w+-\d+\Z/

    if Regex.match?(prefixed_id_pattern, value), do: value, else: nil
  end

  def validate(nil, _), do: nil
  def validate("", _), do: nil
  def validate(value, _), do: value
end
