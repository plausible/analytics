defmodule Plausible.Test.Support.DNS do
  @moduledoc false
  defmacro __using__(_) do
    quote do
      import Mox

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
