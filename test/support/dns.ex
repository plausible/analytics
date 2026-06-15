defmodule Plausible.Test.Support.DNS do
  @moduledoc false
  defmacro __using__(_) do
    quote do
      import Mox

      def stub_lookup_a_records(
            domain,
            a_records \\ [{93, 184, 216, 34}],
            aaaa_records \\ []
          ) do
        lookup_domain = to_charlist(domain)

        Plausible.DnsLookup.Mock
        |> stub(:lookup, fn
          ^lookup_domain, _class, :aaaa, _opts, _timeout -> aaaa_records
          ^lookup_domain, _class, _type, _opts, _timeout -> a_records
        end)
      end
    end
  end
end
