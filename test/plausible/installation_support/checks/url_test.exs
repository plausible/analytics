defmodule Plausible.InstallationSupport.Checks.UrlTest do
  @moduledoc """
  These tests use real DNS lookup
  """
  use Plausible.DataCase, async: true

  alias Plausible.InstallationSupport.{State, Checks, Verification}

  @check Checks.Url

  describe "when domain is set" do
    for domain <- ["plausible.io", "www.plausible.io", "plausible.io/sites"] do
      test "passes domain #{domain}" do
        state =
          @check.perform(%State{
            data_domain: unquote(domain),
            url: nil,
            diagnostics: %Verification.Diagnostics{}
          })

        assert state.url == "https://#{unquote(domain)}"
        refute state.diagnostics.service_error
        refute state.skip_further_checks?
      end
    end

    test "fails for invalid data_domains" do
      state =
        @check.perform(%State{
          data_domain: "foobar.plausible.io",
          url: nil,
          diagnostics: %Verification.Diagnostics{}
        })

      assert state.url == nil
      assert state.diagnostics.service_error == :domain_not_found
      assert state.skip_further_checks?
    end
  end

  describe "when url is set" do
    test "strips query and fragment of legitimate urls" do
      state =
        @check.perform(%State{
          data_domain: "plausible.io",
          url: "https://staging.plausible.io/path?foo=bar#baz",
          diagnostics: %Verification.Diagnostics{}
        })

      assert state.url == "https://staging.plausible.io/path"
      refute state.diagnostics.service_error
      refute state.skip_further_checks?
    end

    for scheme <- ["http", "file"] do
      test "rejects schemes that are not https: #{scheme}" do
        state =
          @check.perform(%State{
            data_domain: "plausible.io",
            url: "#{unquote(scheme)}://staging.plausible.io/path?foo=bar#baz",
            diagnostics: %Verification.Diagnostics{}
          })

        assert state.url == "#{unquote(scheme)}://staging.plausible.io/path?foo=bar#baz"
        assert state.diagnostics.service_error == :invalid_url
        assert state.skip_further_checks?
      end
    end

    test "rejects invalid urls" do
      state =
        @check.perform(%State{
          data_domain: "plausible.io",
          url: "https://foobar.plausible.io/path?foo=bar#baz",
          diagnostics: %Verification.Diagnostics{}
        })

      assert state.url == "https://foobar.plausible.io/path?foo=bar#baz"
      assert state.diagnostics.service_error == :domain_not_found
      assert state.skip_further_checks?
    end
  end

  test "reports progress correctly" do
    assert @check.report_progress_as() ==
             "We're trying to reach your website"
  end
end
