defmodule Plausible.Hash do
  def hash(key, input), do: SipHash.hash!(key, input)
  def hash(input), do: SipHash.hash!(default_key(), input)

  defp default_key() do
    Keyword.fetch!(
      Application.get_env(:plausible, PlausibleWeb.Endpoint),
      :secret_key_base
    )
    |> binary_part(0, 16)
  end
end
