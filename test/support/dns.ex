defmodule Plausible.Test.Support.DNS do
  @moduledoc false

  defmacro __using__(_) do
    quote do
      import Mox

      def stub_dns do
        stub(Plausible.DnsLookup.Mock, :lookup, fn _domain, :in, type, _opts, _timeout ->
          case type do
            :a -> [{93, 184, 216, 34}]
            :aaaa -> []
          end
        end)
      end

      # `%{"domain" => {a_records, aaaa_records}}`
      def stub_dns(mapping) when is_map(mapping) do
        stub(Plausible.DnsLookup.Mock, :lookup, fn domain, :in, type, _opts, _timeout ->
          {a_records, aaaa_records} = Map.fetch!(mapping, List.to_string(domain))
          if type == :a, do: a_records, else: aaaa_records
        end)
      end

      def expect_dns_lookup(domain, a_records, aaaa_records \\ []) do
        lookup_domain = to_charlist(domain)

        Plausible.DnsLookup.Mock
        |> expect(:lookup, fn ^lookup_domain, :in, :a, _opts, _timeout -> a_records end)
        |> expect(:lookup, fn ^lookup_domain, :in, :aaaa, _opts, _timeout -> aaaa_records end)
      end

      def expect_dns_unresolvable(domain), do: expect_dns_lookup(domain, [], [])

      def expect_no_dns_lookup do
        expect(Plausible.DnsLookup.Mock, :lookup, 0, fn _, _, _, _, _ -> [] end)
      end

      def stub_lookup_a_records(domain, a_records \\ [{192, 168, 1, 1}]) do
        lookup_domain = to_charlist(domain)

        Plausible.DnsLookup.Mock
        |> expect(:lookup, fn ^lookup_domain, _type, _record, _opts, _timeout ->
          a_records
        end)
      end
    end
  end
end
