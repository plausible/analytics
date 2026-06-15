defmodule Plausible.InstallationSupport.Checks.UrlTest do
  @moduledoc """
  Tests for URL check that is used in detection and verification checks pipelines
  to fail fast on non-existent domains.
  """

  use Plausible.DataCase, async: true

  on_ee do
    import Mox

    alias Plausible.InstallationSupport.{State, Checks, Verification}

    @check Checks.Url

    describe "when domain is set" do
      for {site_domain, expected_lookup_domain} <- [
            {"plausible.io", ~c"plausible.io"},
            {"www.plausible.io", ~c"www.plausible.io"},
            {"plausible.io/sites", ~c"plausible.io"}
          ] do
        test "guesses 'https://#{site_domain}' if A-record is found for '#{site_domain}'" do
          Plausible.DnsLookup.Mock
          |> stub(:lookup, fn
            unquote(expected_lookup_domain), _class, :aaaa, _opts, _timeout ->
              []

            unquote(expected_lookup_domain), _class, _type, _opts, _timeout ->
              [{93, 184, 216, 34}]
          end)

          state =
            @check.perform(
              %State{
                data_domain: unquote(site_domain),
                url: nil,
                diagnostics: %Verification.Diagnostics{}
              },
              []
            )

          assert state.url == "https://#{unquote(site_domain)}"
          refute state.diagnostics.service_error
          refute state.skip_further_checks?
        end
      end

      test "guesses 'www.{domain}' if A record is not found for 'domain'" do
        site_domain = "example.com/any/deeper/path"

        Plausible.DnsLookup.Mock
        |> expect(:lookup, fn ~c"example.com", _class, :a, _opts, _timeout ->
          []
        end)
        |> stub(:lookup, fn
          ~c"www.example.com", _class, :aaaa, _opts, _timeout -> []
          ~c"www.example.com", _class, _type, _opts, _timeout -> [{93, 184, 216, 35}]
        end)

        state =
          @check.perform(
            %State{
              data_domain: site_domain,
              url: nil,
              diagnostics: %Verification.Diagnostics{}
            },
            []
          )

        assert state.url == "https://www.example.com/any/deeper/path"
        refute state.diagnostics.service_error
        refute state.skip_further_checks?
      end

      test "fails if no A-record is found for 'domain' or 'www.{domain}'" do
        expected_lookups = 2

        Plausible.DnsLookup.Mock
        |> expect(:lookup, expected_lookups, fn _domain, _type, _record, _opts, _timeout ->
          []
        end)

        domain = "any.example.com"

        state =
          @check.perform(
            %State{
              data_domain: domain,
              url: nil,
              diagnostics: %Verification.Diagnostics{}
            },
            []
          )

        assert state.url == nil
        assert state.diagnostics.service_error == %{code: :domain_not_found}
        assert state.skip_further_checks?
      end
    end

    describe "when url is set" do
      test "for legitimate urls on domains that have an A-record, strips query and fragment" do
        site_domain = "example-com-rollup"
        url = "https://blog.example.com/recipes?foo=bar#baz"

        Plausible.DnsLookup.Mock
        |> stub(:lookup, fn
          ~c"blog.example.com", _class, :aaaa, _opts, _timeout -> []
          ~c"blog.example.com", _class, _type, _opts, _timeout -> [{93, 184, 216, 34}]
        end)

        state =
          @check.perform(
            %State{
              data_domain: site_domain,
              url: url,
              diagnostics: %Verification.Diagnostics{}
            },
            []
          )

        assert state.url == "https://blog.example.com/recipes"
        refute state.diagnostics.service_error
        refute state.skip_further_checks?
      end

      test "rejects file:// scheme, does not check domain" do
        state =
          @check.perform(
            %State{
              data_domain: "example-com-rollup",
              url: "file://example.com/archives/news?p=any#fragment",
              diagnostics: %Verification.Diagnostics{}
            },
            []
          )

        assert state.url == "file://example.com/archives/news?p=any#fragment"
        assert state.diagnostics.service_error == %{code: :invalid_url}
        assert state.skip_further_checks?
      end

      test "rejects invalid urls" do
        site_domain = "example-com-rollup"
        url = "https://example.com/archives/news?p=any#fragment"

        Plausible.DnsLookup.Mock
        |> expect(:lookup, fn ~c"example.com", _type, _record, _opts, _timeout ->
          []
        end)

        state =
          @check.perform(
            %State{
              data_domain: site_domain,
              url: url,
              diagnostics: %Verification.Diagnostics{}
            },
            []
          )

        assert state.url == url
        assert state.diagnostics.service_error == %{code: :domain_not_found}
        assert state.skip_further_checks?
      end
    end

    describe "SSRF protection" do
      for {label, a_record} <- [
            {"loopback", {127, 0, 0, 1}},
            {"private 10/8", {10, 0, 0, 5}},
            {"private 192.168/16", {192, 168, 1, 1}},
            {"private 172.16/12", {172, 16, 0, 1}},
            {"link-local metadata", {169, 254, 169, 254}},
            {"CGNAT 100.64/10", {100, 64, 0, 1}}
          ] do
        test "rejects url whose host resolves to #{label}" do
          url = "https://internal.attacker.example/_search"

          Plausible.DnsLookup.Mock
          |> expect(:lookup, fn ~c"internal.attacker.example", _type, _record, _opts, _timeout ->
            [unquote(Macro.escape(a_record))]
          end)

          state =
            @check.perform(
              %State{
                data_domain: "example-com-rollup",
                url: url,
                diagnostics: %Verification.Diagnostics{}
              },
              []
            )

          assert state.url == url
          assert state.diagnostics.service_error == %{code: :domain_not_found}
          assert state.skip_further_checks?
        end

        test "rejects data_domain whose host resolves to #{label}" do
          Plausible.DnsLookup.Mock
          |> expect(:lookup, 2, fn _domain, _type, _record, _opts, _timeout ->
            [unquote(Macro.escape(a_record))]
          end)

          state =
            @check.perform(
              %State{
                data_domain: "internal.attacker.example",
                url: nil,
                diagnostics: %Verification.Diagnostics{}
              },
              []
            )

          assert state.url == nil
          assert state.diagnostics.service_error == %{code: :domain_not_found}
          assert state.skip_further_checks?
        end
      end

      test "rejects host with a public A record but an internal AAAA record" do
        url = "https://dualstack.attacker.example/"

        Plausible.DnsLookup.Mock
        |> stub(:lookup, fn
          ~c"dualstack.attacker.example", _class, :aaaa, _opts, _timeout ->
            [{0, 0, 0, 0, 0, 0, 0, 1}]

          ~c"dualstack.attacker.example", _class, _type, _opts, _timeout ->
            [{93, 184, 216, 34}]
        end)

        state =
          @check.perform(
            %State{
              data_domain: "example-com-rollup",
              url: url,
              diagnostics: %Verification.Diagnostics{}
            },
            []
          )

        assert state.url == url
        assert state.diagnostics.service_error == %{code: :domain_not_found}
        assert state.skip_further_checks?
      end

      test "rejects host that resolves to both public and private addresses" do
        url = "https://rebind.attacker.example/"

        Plausible.DnsLookup.Mock
        |> expect(:lookup, fn ~c"rebind.attacker.example", _type, _record, _opts, _timeout ->
          [{93, 184, 216, 34}, {10, 0, 0, 1}]
        end)

        state =
          @check.perform(
            %State{
              data_domain: "example-com-rollup",
              url: url,
              diagnostics: %Verification.Diagnostics{}
            },
            []
          )

        assert state.url == url
        assert state.diagnostics.service_error == %{code: :domain_not_found}
        assert state.skip_further_checks?
      end
    end

    test "reports progress correctly" do
      assert @check.report_progress_as() ==
               "We're trying to reach your website"
    end
  end
end
