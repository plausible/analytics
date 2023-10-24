defmodule Plausible.ValueHelpers do
  @prefix_pattern "[a-zA-Z]+"
  @id_pattern "\\d+"
  @uuid_pattern "[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}"

  @spec validate(any(), keyword()) :: any()
  def validate(value, type: :prefixed_id) when is_binary(value) do
    pattern = ~r/\A(#{@prefix_pattern})-(#{@id_pattern}|#{@uuid_pattern})\Z/

    if Regex.match?(pattern, value), do: value, else: nil
  end

  def validate(nil, _), do: nil
  def validate("", _), do: nil
  def validate(value, _), do: value
end
