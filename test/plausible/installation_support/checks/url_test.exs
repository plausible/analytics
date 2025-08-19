defmodule Plausible.InstallationSupport.Checks.UrlTest do
  @moduledoc """
  Tests for URL check that is used in detection and verification checks pipelines
  to fail fast on non-existent domains.
  """
  use Plausible.DataCase, async: true
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
        |> expect(:lookup, fn unquote(expected_lookup_domain), _type, _record, _opts, _timeout ->
          [{192, 168, 1, 1}]
        end)

        state =
          @check.perform(%State{
            data_domain: unquote(site_domain),
            url: nil,
            diagnostics: %Verification.Diagnostics{}
          })

        assert state.url == "https://#{unquote(site_domain)}"
        refute state.diagnostics.service_error
        refute state.skip_further_checks?
      end
    end

    test "guesses 'www.{domain}' if A record is not found for 'domain'" do
      site_domain = "example.com/any/deeper/path"

      Plausible.DnsLookup.Mock
      |> expect(:lookup, fn ~c"example.com", _type, _record, _opts, _timeout ->
        []
      end)
      |> expect(:lookup, fn ~c"www.example.com", _type, _record, _opts, _timeout ->
        [{192, 168, 1, 2}]
      end)

      state =
        @check.perform(%State{
          data_domain: site_domain,
          url: nil,
          diagnostics: %Verification.Diagnostics{}
        })

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
        @check.perform(%State{
          data_domain: domain,
          url: nil,
          diagnostics: %Verification.Diagnostics{}
        })

      assert state.url == nil
      assert state.diagnostics.service_error == :domain_not_found
      assert state.skip_further_checks?
    end
  end

  describe "when url is set" do
    test "for legitimate urls on domains that have an A-record, strips query and fragment" do
      site_domain = "example-com-rollup"
      url = "https://blog.example.com/recipes?foo=bar#baz"

      Plausible.DnsLookup.Mock
      |> expect(:lookup, fn ~c"blog.example.com", _type, _record, _opts, _timeout ->
        [{192, 168, 1, 1}]
      end)

      state =
        @check.perform(%State{
          data_domain: site_domain,
          url: url,
          diagnostics: %Verification.Diagnostics{}
        })

      assert state.url == "https://blog.example.com/recipes"
      refute state.diagnostics.service_error
      refute state.skip_further_checks?
    end

    for scheme <- ["http", "file"] do
      test "rejects not-https scheme '#{scheme}', does not check domain" do
        state =
          @check.perform(%State{
            data_domain: "example-com-rollup",
            url: "#{unquote(scheme)}://example.com/archives/news?p=any#fragment",
            diagnostics: %Verification.Diagnostics{}
          })

        assert state.url == "#{unquote(scheme)}://example.com/archives/news?p=any#fragment"
        assert state.diagnostics.service_error == :invalid_url
        assert state.skip_further_checks?
      end
    end

    test "rejects invalid urls" do
      site_domain = "example-com-rollup"
      url = "https://example.com/archives/news?p=any#fragment"

      Plausible.DnsLookup.Mock
      |> expect(:lookup, fn ~c"example.com", _type, _record, _opts, _timeout ->
        []
      end)

      state =
        @check.perform(%State{
          data_domain: site_domain,
          url: url,
          diagnostics: %Verification.Diagnostics{}
        })

      assert state.url == url
      assert state.diagnostics.service_error == :domain_not_found
      assert state.skip_further_checks?
    end
  end

  test "reports progress correctly" do
    assert @check.report_progress_as() ==
             "We're trying to reach your website"
  end
end
