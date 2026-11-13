defmodule Plausible.Test.Support.DNS do
  @moduledoc false

  # Dev compiles test/support too, but Mox is test-only.
  @compile {:no_warn_undefined, Mox}

  defmacro __using__(_) do
    quote do
      import Mox
      import Plausible.Test.Support.DNS
    end
  end

  def stub_dns do
    Mox.stub(Plausible.DnsLookup.Mock, :lookup, fn _domain, :in, type, _opts, _timeout ->
      case type do
        :a -> [{93, 184, 216, 34}]
        :aaaa -> []
      end
    end)
  end

  # `%{"domain" => {a_records, aaaa_records}}`
  def stub_dns(mapping) when is_map(mapping) do
    Mox.stub(Plausible.DnsLookup.Mock, :lookup, fn domain, :in, type, _opts, _timeout ->
      {a_records, aaaa_records} = Map.fetch!(mapping, List.to_string(domain))
      if type == :a, do: a_records, else: aaaa_records
    end)
  end

  def expect_dns_lookup(domain, a_records, aaaa_records \\ []) do
    lookup_domain = to_charlist(domain)

    Plausible.DnsLookup.Mock
    |> Mox.expect(:lookup, fn ^lookup_domain, :in, :a, _opts, _timeout -> a_records end)
    |> Mox.expect(:lookup, fn ^lookup_domain, :in, :aaaa, _opts, _timeout -> aaaa_records end)
  end

  def expect_dns_unresolvable(domain), do: expect_dns_lookup(domain, [], [])

  def expect_no_dns_lookup do
    Mox.expect(Plausible.DnsLookup.Mock, :lookup, 0, fn _, _, _, _, _ -> [] end)
  end
end
