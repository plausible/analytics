defmodule Plausible.InstallationSupport.Checks.UrlTest do
  @moduledoc """
  Tests for URL check that is used in detection and verification checks pipelines
  to fail fast on non-existent domains.
  """

  use Plausible.DataCase, async: true

  on_ee do
    use Plausible.Test.Support.DNS

    alias Plausible.InstallationSupport.{Checks, State, Verification}

    @check Checks.Url

    describe "when domain is set" do
      for {site_domain, expected_lookup_domain} <- [
            {"plausible.io", ~c"plausible.io"},
            {"www.plausible.io", ~c"www.plausible.io"},
            {"plausible.io/sites", ~c"plausible.io"}
          ] do
        test "guesses 'https://#{site_domain}' if A-record is found for '#{site_domain}'" do
          expect_dns_lookup(unquote(expected_lookup_domain), [{93, 184, 216, 34}])

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

        expect_dns_lookup("example.com", [])
        expect_dns_lookup("www.example.com", [{93, 184, 216, 34}])

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
        domain = "any.example.com"

        expect_dns_lookup("any.example.com", [])
        expect_dns_lookup("www.any.example.com", [])

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

      test "fails if 'domain' only resolves to a private/reserved address" do
        domain = "any.example.com"

        expect_dns_lookup("any.example.com", [{192, 168, 1, 1}])
        expect_dns_lookup("www.any.example.com", [])

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

      test "fails if 'domain' only resolves to a private/reserved AAAA address" do
        domain = "any.example.com"

        expect_dns_lookup("any.example.com", [], [{0xFC00, 0, 0, 0, 0, 0, 0, 1}])
        expect_dns_lookup("www.any.example.com", [])

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

        expect_dns_lookup("blog.example.com", [{93, 184, 216, 34}])

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

        expect_dns_lookup("example.com", [])

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

      test "rejects urls whose host only resolves to a private/reserved address" do
        site_domain = "example-com-rollup"
        url = "https://example.com/archives/news?p=any#fragment"

        expect_dns_lookup("example.com", [{127, 0, 0, 1}])

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

    test "reports progress correctly" do
      assert @check.report_progress_as() ==
               "We're trying to reach your website"
    end
  end
end
