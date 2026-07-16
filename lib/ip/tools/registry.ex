defmodule Plausible.IP.Tools.Registry do
  @moduledoc """
  Compile-time-only helpers for `Plausible.IP.Tools`. 

  Parses IANA RFC4180 CSV plus supplemental multicast ranges 
  into a list of function clause meta data.
  """

  import Bitwise

  def ipv4_registry_path,
    do: Application.app_dir(:plausible, "priv/ip/iana-ipv4-special-registry.csv")

  def ipv6_registry_path,
    do: Application.app_dir(:plausible, "priv/ip/iana-ipv6-special-registry.csv")

  def entries() do
    ipv4 = load(ipv4_registry_path())

    ipv6 =
      ipv6_registry_path()
      |> load()
      # IPv4-mapped IPv6 is excluded here: it isn't a range
      # that's uniformly reserved or public, it's a container for an entire
      # embedded IPv4 address. Plausible.IP.Tools handles it by unwrapping
      # the embedded address and delegating back to the IPv4 clauses instead.
      |> Enum.reject(&(&1.cidr == "::ffff:0:0/96"))

    (ipv4 ++ ipv6 ++ multicast())
    |> Enum.sort_by(&(-&1.prefix_len))
    |> Enum.map(&to_clause/1)
  end

  defp multicast do
    [
      entry_from_cidr("224.0.0.0/4", "Multicast", true),
      entry_from_cidr("ff00::/8", "Multicast", true)
    ]
  end

  defp rows_to_entries(rows), do: Enum.flat_map(rows, &row_to_entry/1)

  # Address Block,Name,RFC,Allocation Date,Termination Date,Source,
  # Destination,Forwardable,Globally Reachable,Reserved-by-Protocol
  defp row_to_entry(row) do
    address_block = Enum.at(row, 0)
    name = Enum.at(row, 1)
    termination_date = row |> Enum.at(4) |> strip_footnotes()
    globally_reachable = row |> Enum.at(8) |> strip_footnotes()

    reserved? = termination_date == "N/A" and globally_reachable == "False"

    address_block
    |> strip_footnotes()
    |> String.split(",")
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
    |> Enum.map(&entry_from_cidr(&1, name, reserved?))
  end

  defp strip_footnotes(nil), do: nil

  defp strip_footnotes(field) do
    field
    |> String.replace(~r/\s*\[\d+\]/, "")
    |> String.trim()
  end

  defp entry_from_cidr(cidr, name, reserved?) do
    [addr_str, prefix_str] = String.split(cidr, "/")
    {:ok, address} = :inet.parse_address(String.to_charlist(addr_str))

    %{
      cidr: cidr,
      name: name,
      words: Tuple.to_list(address),
      prefix_len: String.to_integer(prefix_str),
      reserved: reserved?
    }
  end

  defp to_clause(%{
         words: words,
         prefix_len: prefix_len,
         reserved: reserved,
         cidr: cidr,
         name: name
       }) do
    word_bits = if length(words) == 4, do: 8, else: 16
    indexed_words = Enum.with_index(words)

    pattern_words = Enum.map(indexed_words, &pattern_word(&1, word_bits, prefix_len))

    guard =
      indexed_words
      |> Enum.map(&guard_for_word(&1, word_bits, prefix_len))
      |> Enum.reject(&is_nil/1)
      |> combine_guards()

    %{pattern: {:{}, [], pattern_words}, guard: guard, reserved: reserved, cidr: cidr, name: name}
  end

  defp pattern_word({word, index}, word_bits, prefix_len) do
    bits_before = index * word_bits
    bits_after = bits_before + word_bits

    cond do
      bits_after <= prefix_len -> word
      bits_before >= prefix_len -> Macro.var(:"_w#{index}", nil)
      true -> Macro.var(:"w#{index}", nil)
    end
  end

  defp guard_for_word({word, index}, word_bits, prefix_len) do
    bits_before = index * word_bits
    bits_after = bits_before + word_bits

    if bits_before < prefix_len and bits_after > prefix_len do
      var = Macro.var(:"w#{index}", nil)
      bits_in_word = prefix_len - bits_before
      free_bits = word_bits - bits_in_word
      full_mask = (1 <<< word_bits) - 1
      mask = full_mask - ((1 <<< free_bits) - 1)
      masked_value = word &&& mask

      quote do
        band(unquote(var), unquote(mask)) === unquote(masked_value)
      end
    end
  end

  defp combine_guards([]), do: true
  defp combine_guards([guard]), do: guard

  defp combine_guards([guard | rest]) do
    Enum.reduce(rest, guard, fn g, acc ->
      quote do
        unquote(acc) and unquote(g)
      end
    end)
  end

  defp load(path) do
    path
    |> File.read!()
    |> NimbleCSV.RFC4180.parse_string()
    |> rows_to_entries()
  end
end
