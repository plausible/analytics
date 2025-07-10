defmodule Plausible.Verification.ChecksTest do
  use Plausible.DataCase, async: true

  alias Plausible.Verification.Checks
  alias Plausible.Verification.Diagnostics
  alias Plausible.Verification.State

  import ExUnit.CaptureLog
  import Plug.Conn

  @errors Plausible.Verification.Errors.all()

  describe "successful verification" do
    @normal_body """
    <html>
    <head>
    <script defer data-domain="example.com" src="http://localhost:8000/js/script.js"></script>
    </head>
    <body>Hello</body>
    </html>
    """

    test "definite success" do
      stub_fetch_body(200, @normal_body)
      stub_installation()

      run_checks()
      |> Checks.interpret_diagnostics()
      |> assert_ok()
    end

    test "fetching will follow 2 redirects" do
      ref = :counters.new(1, [:atomics])
      test = self()

      Req.Test.stub(Plausible.Verification.Checks.FetchBody, fn conn ->
        if :counters.get(ref, 1) < 2 do
          :counters.add(ref, 1, 1)
          send(test, :redirect_sent)

          conn
          |> put_resp_header("location", "https://example.com")
          |> send_resp(302, "redirecting to https://example.com")
        else
          conn
          |> put_resp_header("content-type", "text/html")
          |> send_resp(200, @normal_body)
        end
      end)

      stub_installation()

      run_checks()
      |> Checks.interpret_diagnostics()
      |> assert_ok()

      assert_receive :redirect_sent
      assert_receive :redirect_sent
      refute_receive _
    end

    test "allowed via content-security-policy" do
      stub_fetch_body(fn conn ->
        conn
        |> put_resp_header(
          "content-security-policy",
          Enum.random([
            "default-src 'self'; script-src plausible.io; connect-src #{PlausibleWeb.Endpoint.host()}",
            "default-src 'self' *.#{PlausibleWeb.Endpoint.host()}"
          ])
        )
        |> put_resp_content_type("text/html")
        |> send_resp(200, @normal_body)
      end)

      stub_installation()

      run_checks()
      |> Checks.interpret_diagnostics()
      |> assert_ok()
    end

    @proxied_script_body """
    <html>
    <head>
    <script defer data-domain="example.com" src="https://proxy.example.com/js/script.js"></script>
    </head>
    <body>Hello</body>
    </html>
    """

    test "proxied setup working OK" do
      stub_fetch_body(200, @proxied_script_body)
      stub_installation()

      run_checks()
      |> Checks.interpret_diagnostics()
      |> assert_ok()
    end

    @body_no_snippet """
    <html> <head> </head> <body> Hello </body> </html>
    """

    test "non-standard integration where the snippet cannot be found but it works ok in headless" do
      stub_fetch_body(200, @body_no_snippet)
      stub_installation(200, plausible_installed(true, 202))

      run_checks()
      |> Checks.interpret_diagnostics()
      |> assert_ok()
    end

    @different_data_domain_body """
    <html>
    <head>
    <script defer data-domain="www.example.com" src="http://localhost:8000/js/script.js"></script>
    </head>
    <body>Hello</body>
    </html>
    """

    test "data-domain mismatch on redirect chain" do
      ref = :counters.new(1, [:atomics])
      test = self()

      Req.Test.stub(Plausible.Verification.Checks.FetchBody, fn conn ->
        if :counters.get(ref, 1) == 0 do
          :counters.add(ref, 1, 1)
          send(test, :redirect_sent)

          conn
          |> put_resp_header("location", "https://www.example.com")
          |> send_resp(302, "redirecting to https://www.example.com")
        else
          conn
          |> put_resp_header("content-type", "text/html")
          |> send_resp(200, @different_data_domain_body)
        end
      end)

      stub_installation()

      run_checks()
      |> Checks.interpret_diagnostics()
      |> assert_ok()

      assert_receive :redirect_sent
    end
  end

  describe "errors" do
    test "service error - 400" do
      stub_fetch_body(200, @normal_body)
      stub_installation(400, %{})

      run_checks()
      |> Checks.interpret_diagnostics()
      |> assert_error(@errors.temporary)
    end

    @tag :slow
    test "can't fetch body but headless reports ok" do
      stub_fetch_body(500, "")
      stub_installation()

      {_, log} =
        with_log(fn ->
          run_checks()
          |> Checks.interpret_diagnostics()
          |> assert_ok()
        end)

      assert log =~ "3 attempts left"
      assert log =~ "2 attempts left"
      assert log =~ "1 attempt left"
    end

    test "fetching will give up at 5th redirect" do
      test = self()

      stub_fetch_body(fn conn ->
        send(test, :redirect_sent)

        conn
        |> put_resp_header("location", "https://example.com")
        |> send_resp(302, "redirecting to https://example.com")
      end)

      stub_installation()

      run_checks()
      |> Checks.interpret_diagnostics()
      |> assert_error(@errors.unreachable, url: "https://example.com")

      assert_receive :redirect_sent
      assert_receive :redirect_sent
      assert_receive :redirect_sent
      assert_receive :redirect_sent
      assert_receive :redirect_sent
      refute_receive _
    end

    @snippet_in_body """
    <html>
    <head>
    </head>
    <body>
    Hello
    <script defer data-domain="example.com" src="http://localhost:8000/js/script.js"></script>
    </body>
    </html>
    """

    test "detecting snippet in body" do
      stub_fetch_body(200, @snippet_in_body)
      stub_installation()

      run_checks()
      |> Checks.interpret_diagnostics()
      |> assert_error(@errors.snippet_in_body)
    end

    @many_snippets """
    <html>
    <head>
    <script defer data-domain="example.com" src="https://plausible.io/js/script.js"></script>
    <script defer data-domain="example.com" src="https://plausible.io/js/script.js"></script>
    </head>
    <body>
    Hello
    <script defer data-domain="example.com" src="https://plausible.io/js/script.js"></script>
    <script defer data-domain="example.com" src="https://plausible.io/js/script.js"></script>
    <!-- maybe proxy? -->
    <script defer data-domain="example.com" src="https://example.com/js/script.js"></script>
    </body>
    </html>
    """

    test "detecting many snippets" do
      stub_fetch_body(200, @many_snippets)
      stub_installation()

      run_checks()
      |> Checks.interpret_diagnostics()
      |> assert_error(@errors.multiple_snippets)
    end

    @no_src_scripts """
    <html>
    <head>
    <script defer data-domain="example.com"></script>
    </head>
    <body>
    Hello
    <script defer data-domain="example.com"></script>
    </body>
    </html>
    """
    test "no src attr doesn't count as snippet" do
      stub_fetch_body(200, @no_src_scripts)
      stub_installation(200, plausible_installed(false))

      run_checks()
      |> Checks.interpret_diagnostics()
      |> assert_error(@errors.no_snippet)
    end

    @many_snippets_ok """
    <html>
    <head>
    <script defer data-domain="example.com" src="https://plausible.io/js/script.js"></script>
    <script defer data-domain="example.com" src="https://plausible.io/js/script.manual.js"></script>
    </head>
    <body>
    Hello
    </body>
    </html>
    """

    test "skipping many snippets when manual found" do
      stub_fetch_body(200, @many_snippets_ok)
      stub_installation()

      run_checks()
      |> Checks.interpret_diagnostics()
      |> assert_ok()
    end

    test "detecting snippet after busting cache" do
      stub_fetch_body(fn conn ->
        conn = fetch_query_params(conn)

        if conn.query_params["plausible_verification"] do
          conn
          |> put_resp_content_type("text/html")
          |> send_resp(200, @normal_body)
        else
          conn
          |> put_resp_content_type("text/html")
          |> send_resp(200, @body_no_snippet)
        end
      end)

      stub_installation(fn conn ->
        {:ok, body, _} = read_body(conn)

        if String.contains?(body, "?plausible_verification") do
          conn
          |> put_resp_content_type("application/json")
          |> send_resp(200, Jason.encode!(plausible_installed()))
        else
          raise "Should not get here even"
        end
      end)

      run_checks()
      |> Checks.interpret_diagnostics()
      |> assert_error(@errors.cache_general)
    end

    @normal_body_wordpress """
    <html>
    <head>
    <meta name="foo" content="/wp-content/plugins/bar"/>
    <script defer data-domain="example.com" src="http://localhost:8000/js/script.js"></script>
    </head>
    <body>Hello</body>
    </html>
    """

    test "detecting snippet after busting WordPress cache - no official plugin" do
      stub_fetch_body(fn conn ->
        conn = fetch_query_params(conn)

        if conn.query_params["plausible_verification"] do
          conn
          |> put_resp_content_type("text/html")
          |> send_resp(200, @normal_body_wordpress)
        else
          conn
          |> put_resp_content_type("text/html")
          |> send_resp(200, @body_no_snippet)
        end
      end)

      stub_installation(fn conn ->
        {:ok, body, _} = read_body(conn)

        if String.contains?(body, "?plausible_verification") do
          conn
          |> put_resp_content_type("application/json")
          |> send_resp(200, Jason.encode!(plausible_installed()))
        else
          raise "Should not get here even"
        end
      end)

      run_checks()
      |> Checks.interpret_diagnostics()
      |> assert_error(@errors.cache_wp_no_plugin)
    end

    @normal_body_wordpress_official_plugin """
    <html>
    <head>
    <meta name="foo" content="/wp-content/plugins/bar"/>
    <meta name='plausible-analytics-version' content='2.0.9' />
    <script defer data-domain="example.com" src="http://localhost:8000/js/script.js"></script>
    </head>
    <body>Hello</body>
    </html>
    """

    test "detecting snippet after busting WordPress cache - official plugin" do
      stub_fetch_body(fn conn ->
        conn = fetch_query_params(conn)

        if conn.query_params["plausible_verification"] do
          conn
          |> put_resp_content_type("text/html")
          |> send_resp(200, @normal_body_wordpress_official_plugin)
        else
          conn
          |> put_resp_content_type("text/html")
          |> send_resp(200, @body_no_snippet)
        end
      end)

      stub_installation(fn conn ->
        {:ok, body, _} = read_body(conn)

        if String.contains?(body, "?plausible_verification") do
          conn
          |> put_resp_content_type("application/json")
          |> send_resp(200, Jason.encode!(plausible_installed()))
        else
          raise "Should not get here even"
        end
      end)

      run_checks()
      |> Checks.interpret_diagnostics()
      |> assert_error(@errors.cache_wp_plugin)
    end

    test "detecting no snippet" do
      stub_fetch_body(200, @body_no_snippet)
      stub_installation(200, plausible_installed(false))

      run_checks()
      |> Checks.interpret_diagnostics()
      |> assert_error(@errors.no_snippet)
    end

    @body_no_snippet_wp """
    <html>
    <head>
    <meta name="foo" content="/wp-content/plugins/bar"/>
    </head>
    <body>
    Hello
    </body>
    </html>
    """

    test "detecting no snippet on a wordpress site" do
      stub_fetch_body(200, @body_no_snippet_wp)
      stub_installation(200, plausible_installed(false))

      run_checks()
      |> Checks.interpret_diagnostics()
      |> assert_error(@errors.no_snippet_wp)
    end

    test "a check that raises" do
      defmodule FaultyCheckRaise do
        use Plausible.Verification.Check

        @impl true
        def report_progress_as, do: "Faulty check"

        @impl true
        def perform(_), do: raise("boom")
      end

      {result, log} =
        with_log(fn ->
          run_checks(checks: [FaultyCheckRaise])
        end)

      assert log =~
               ~s|Error running check Plausible.Verification.ChecksTest.FaultyCheckRaise on https://example.com: %RuntimeError{message: "boom"}|

      result
      |> Checks.interpret_diagnostics()
      |> assert_error(@errors.unreachable, url: "https://example.com")
    end

    test "a check that throws" do
      defmodule FaultyCheckThrow do
        use Plausible.Verification.Check

        @impl true
        def report_progress_as, do: "Faulty check"

        @impl true
        def perform(_), do: :erlang.throw(:boom)
      end

      {result, log} =
        with_log(fn ->
          run_checks(checks: [FaultyCheckThrow])
        end)

      assert log =~
               ~s|Error running check Plausible.Verification.ChecksTest.FaultyCheckThrow on https://example.com: :boom|

      result
      |> Checks.interpret_diagnostics()
      |> assert_error(@errors.unreachable, url: "https://example.com")
    end

    test "disallowed via content-security-policy" do
      stub_fetch_body(fn conn ->
        conn
        |> put_resp_header("content-security-policy", "default-src 'self' foo.local")
        |> put_resp_content_type("text/html")
        |> send_resp(200, @normal_body)
      end)

      stub_installation(200, plausible_installed(false))

      run_checks()
      |> Checks.interpret_diagnostics()
      |> assert_error(@errors.csp)
    end

    test "disallowed via content-security-policy with no snippet should make the latter a priority" do
      stub_fetch_body(fn conn ->
        conn
        |> put_resp_header("content-security-policy", "default-src 'self' foo.local")
        |> put_resp_content_type("text/html")
        |> send_resp(200, @body_no_snippet)
      end)

      stub_installation(200, plausible_installed(false))

      run_checks()
      |> Checks.interpret_diagnostics()
      |> assert_error(@errors.no_snippet)
    end

    test "running checks sends progress messages" do
      stub_fetch_body(200, @normal_body)
      stub_installation()

      final_state = run_checks(report_to: self())

      assert_receive {:verification_check_start, {Checks.FetchBody, %State{}}}
      assert_receive {:verification_check_start, {Checks.CSP, %State{}}}
      assert_receive {:verification_check_start, {Checks.ScanBody, %State{}}}
      assert_receive {:verification_check_start, {Checks.Snippet, %State{}}}
      assert_receive {:verification_check_start, {Checks.SnippetCacheBust, %State{}}}
      assert_receive {:verification_check_start, {Checks.Installation, %State{}}}
      assert_receive {:verification_end, %State{} = ^final_state}
      refute_receive _
    end

    @gtm_body """
    <html>
    <head>
    <!-- Google Tag Manager -->
    <script>(function(w,d,s,l,i){w[l]=w[l]||[];w[l].push({'gtm.start':
    new Date().getTime(),event:'gtm.js'});var f=d.getElementsByTagName(s)[0],
    j=d.createElement(s),dl=l!='dataLayer'?'&l='+l:'';j.async=true;j.src=
    'https://www.googletagmanager.com/gtm.js?id='+i+dl;f.parentNode.insertBefore(j,f);
    })(window,document,'script','dataLayer','XXXX');</script>
    <!-- End Google Tag Manager -->
    </head>
    <body>
    Hello
    </body>
    </html>
    """

    test "disallowed via content-security-policy and GTM should make CSP a priority" do
      stub_fetch_body(fn conn ->
        conn
        |> put_resp_header("content-security-policy", "default-src 'self' foo.local")
        |> put_resp_content_type("text/html")
        |> send_resp(200, @gtm_body)
      end)

      stub_installation(200, plausible_installed(false))

      run_checks()
      |> Checks.interpret_diagnostics()
      |> assert_error(@errors.csp)
    end

    test "detecting gtm" do
      stub_fetch_body(200, @gtm_body)
      stub_installation(200, plausible_installed(false))

      run_checks()
      |> Checks.interpret_diagnostics()
      |> assert_error(@errors.gtm)
    end

    @gtm_body_with_cookiebot """
    <html>
    <head>
    <!-- Google Tag Manager -->
    <script>(function(w,d,s,l,i){w[l]=w[l]||[];w[l].push({'gtm.start':
      new Date().getTime(),event:'gtm.js'});var f=d.getElementsByTagName(s)[0],
      j=d.createElement(s),dl=l!='dataLayer'?'&l='+l:'';j.async=true;j.src=
        'https://www.googletagmanager.com/gtm.js?id='+i+dl;f.parentNode.insertBefore(j,f);
    })(window,document,'script','dataLayer','XXXX');</script>
    <!-- End Google Tag Manager -->
    <script id="Cookiebot" src="https://consent.cookiebot.com/uc.js" data-cbid="some-uuid" data-blockingmode="auto" type="text/javascript"></script>
    </head>
    <body>
    Hello
    </body>
    </html>
    """

    test "detecting gtm with cookie consent" do
      stub_fetch_body(200, @gtm_body_with_cookiebot)
      stub_installation(200, plausible_installed(false))

      run_checks()
      |> Checks.interpret_diagnostics()
      |> assert_error(@errors.gtm_cookie_banner)
    end

    test "non-html body" do
      stub_fetch_body(fn conn ->
        conn
        |> put_resp_content_type("image/png")
        |> send_resp(200, :binary.copy(<<0>>, 100))
      end)

      stub_installation(200, plausible_installed(false))

      run_checks()
      |> Checks.interpret_diagnostics()
      |> assert_error(@errors.unreachable, url: "https://example.com")
    end

    test "proxied setup, function defined but callback won't fire" do
      stub_fetch_body(200, @proxied_script_body)
      stub_installation(200, plausible_installed(true, 0))

      run_checks()
      |> Checks.interpret_diagnostics()
      |> assert_error(@errors.proxy_misconfigured)
    end

    @proxied_script_body_wordpress """
    <html>
    <head>
    <meta name="foo" content="/wp-content/plugins/bar"/>
    <script defer data-domain="example.com" src="https://proxy.example.com/js/script.js"></script>
    </head>
    <body>Hello</body>
    </html>
    """

    test "proxied WordPress setup, function undefined, callback won't fire" do
      stub_fetch_body(200, @proxied_script_body_wordpress)
      stub_installation(200, plausible_installed(false, 0))

      run_checks()
      |> Checks.interpret_diagnostics()
      |> assert_error(@errors.proxy_wp_no_plugin)
    end

    test "proxied setup, function undefined, callback won't fire" do
      stub_fetch_body(200, @proxied_script_body)
      stub_installation(200, plausible_installed(false, 0))

      result = run_checks()
      interpretation = Checks.interpret_diagnostics(result)

      refute interpretation.ok?
      assert interpretation.errors == ["We encountered an error with your Plausible proxy"]

      run_checks()
      |> Checks.interpret_diagnostics()
      |> assert_error(@errors.proxy_general)
    end

    test "non-proxied setup, but callback fails to fire" do
      stub_fetch_body(200, @normal_body)
      stub_installation(200, plausible_installed(true, 0))

      run_checks()
      |> Checks.interpret_diagnostics()
      |> assert_error(@errors.unknown)
    end

    @body_unknown_attributes """
    <html>
    <head>
    <script foo="bar" defer data-domain="example.com" src="http://localhost:8000/js/script.js"></script>
    </head>
    <body>Hello</body>
    </html>
    """

    test "unknown attributes" do
      stub_fetch_body(200, @body_unknown_attributes)
      stub_installation(200, plausible_installed(false, 0))

      run_checks()
      |> Checks.interpret_diagnostics()
      |> assert_error(@errors.illegal_attrs_general)
    end

    @body_unknown_attributes_wordpress """
    <html>
    <head>
    <meta name="foo" content="/wp-content/plugins/bar"/>
    <script foo="bar" defer data-domain="example.com" src="http://localhost:8000/js/script.js"></script>
    </head>
    <body>Hello</body>
    </html>
    """

    test "unknown attributes for WordPress installation" do
      stub_fetch_body(200, @body_unknown_attributes_wordpress)
      stub_installation(200, plausible_installed(false, 0))

      run_checks()
      |> Checks.interpret_diagnostics()
      |> assert_error(@errors.illegal_attrs_wp_no_plugin)
    end

    @body_unknown_attributes_wordpress_official_plugin """
    <html>
    <head>
    <meta name="foo" content="/wp-content/plugins/bar"/>
    <meta name='plausible-analytics-version' content='2.0.9' />
    <script foo="bar" defer data-domain="example.com" src="http://localhost:8000/js/script.js"></script>
    </head>
    <body>Hello</body>
    </html>
    """

    test "unknown attributes for WordPress installation - official plugin" do
      stub_fetch_body(200, @body_unknown_attributes_wordpress_official_plugin)
      stub_installation(200, plausible_installed(false, 0))

      run_checks()
      |> Checks.interpret_diagnostics()
      |> assert_error(@errors.illegal_attrs_wp_plugin)
    end

    test "callback handling not found for non-wordpress site" do
      stub_fetch_body(200, @normal_body)
      stub_installation(200, plausible_installed(true, -1))

      run_checks()
      |> Checks.interpret_diagnostics()
      |> assert_error(@errors.generic)
    end

    test "callback handling not found for wordpress site" do
      stub_fetch_body(200, @normal_body_wordpress)
      stub_installation(200, plausible_installed(true, -1))

      run_checks()
      |> Checks.interpret_diagnostics()
      |> assert_error(@errors.old_script_wp_no_plugin)
    end

    test "callback handling not found for wordpress site using our plugin" do
      stub_fetch_body(200, @normal_body_wordpress_official_plugin)
      stub_installation(200, plausible_installed(true, -1))

      run_checks()
      |> Checks.interpret_diagnostics()
      |> assert_error(@errors.old_script_wp_plugin)
    end

    test "fails due to callback status being something unlikely like 500" do
      stub_fetch_body(200, @normal_body)
      stub_installation(200, plausible_installed(true, 500))

      run_checks()
      |> Checks.interpret_diagnostics()
      |> assert_error(@errors.unknown)
    end

    test "data-domain mismatch" do
      stub_fetch_body(200, @different_data_domain_body)
      stub_installation()

      run_checks()
      |> Checks.interpret_diagnostics()
      |> assert_error(@errors.different_data_domain, domain: "example.com")
    end

    @many_snippets_with_domain_mismatch """
    <html>
    <head>
    <script defer data-domain="example.org" src="https://plausible.io/js/script.js"></script>
    <script defer data-domain="example.org" src="https://plausible.io/js/script.js"></script>
    </head>
    <body>
    Hello
    </body>
    </html>
    """

    test "prioritizes data-domain mismatch over multiple snippets" do
      stub_fetch_body(200, @many_snippets_with_domain_mismatch)
      stub_installation()

      run_checks()
      |> Checks.interpret_diagnostics()
      |> assert_error(@errors.different_data_domain, domain: "example.com")
    end
  end

  describe "unhhandled cases from sentry" do
    test "APP-58: 4b1435e3f8a048eb949cc78fa578d1e4" do
      %Plausible.Verification.Diagnostics{
        plausible_installed?: true,
        snippets_found_in_head: 0,
        snippets_found_in_body: 0,
        snippet_found_after_busting_cache?: false,
        snippet_unknown_attributes?: false,
        disallowed_via_csp?: false,
        service_error: nil,
        body_fetched?: true,
        wordpress_likely?: true,
        cookie_banner_likely?: false,
        gtm_likely?: false,
        callback_status: -1,
        proxy_likely?: false,
        manual_script_extension?: false,
        data_domain_mismatch?: false,
        wordpress_plugin?: false
      }
      |> interpret_sentry_case()
      |> assert_error(@errors.old_script_wp_no_plugin)
    end

    test "service timeout" do
      %Plausible.Verification.Diagnostics{
        plausible_installed?: false,
        snippets_found_in_head: 1,
        snippets_found_in_body: 0,
        snippet_found_after_busting_cache?: false,
        snippet_unknown_attributes?: false,
        disallowed_via_csp?: false,
        service_error: :timeout,
        body_fetched?: true,
        wordpress_likely?: true,
        cookie_banner_likely?: false,
        gtm_likely?: false,
        callback_status: 0,
        proxy_likely?: true,
        manual_script_extension?: false,
        data_domain_mismatch?: false,
        wordpress_plugin?: false
      }
      |> interpret_sentry_case()
      |> assert_error(@errors.generic)
    end

    test "malformed snippet code, that headless somewhat accepts" do
      %Plausible.Verification.Diagnostics{
        plausible_installed?: true,
        snippets_found_in_head: 0,
        snippets_found_in_body: 0,
        snippet_found_after_busting_cache?: false,
        snippet_unknown_attributes?: false,
        disallowed_via_csp?: false,
        service_error: nil,
        body_fetched?: true,
        wordpress_likely?: false,
        cookie_banner_likely?: false,
        gtm_likely?: false,
        callback_status: 405,
        proxy_likely?: false,
        manual_script_extension?: false,
        data_domain_mismatch?: false,
        wordpress_plugin?: false
      }
      |> interpret_sentry_case()
      |> assert_error(@errors.no_snippet)
    end

    test "gtm+wp detected, but likely script id attribute interfering" do
      %Plausible.Verification.Diagnostics{
        plausible_installed?: false,
        snippets_found_in_head: 1,
        snippets_found_in_body: 0,
        snippet_found_after_busting_cache?: false,
        snippet_unknown_attributes?: true,
        disallowed_via_csp?: false,
        service_error: nil,
        body_fetched?: true,
        wordpress_likely?: true,
        cookie_banner_likely?: true,
        gtm_likely?: true,
        callback_status: 0,
        proxy_likely?: true,
        manual_script_extension?: false,
        data_domain_mismatch?: false,
        wordpress_plugin?: true
      }
      |> interpret_sentry_case()
      |> assert_error(@errors.illegal_attrs_wp_plugin)
    end
  end

  defp interpret_sentry_case(diagnostics) do
    diagnostics
    |> Diagnostics.interpret("example.com")
    |> refute_unhandled()
  end

  defp run_checks(extra_opts \\ []) do
    Checks.run(
      "https://example.com",
      "example.com",
      Keyword.merge([async?: false, report_to: nil, slowdown: 0], extra_opts)
    )
  end

  defp stub_fetch_body(f) when is_function(f, 1) do
    Req.Test.stub(Plausible.Verification.Checks.FetchBody, f)
  end

  defp stub_installation(f) when is_function(f, 1) do
    Req.Test.stub(Plausible.Verification.Checks.Installation, f)
  end

  defp stub_fetch_body(status, body) do
    stub_fetch_body(fn conn ->
      conn
      |> put_resp_content_type("text/html")
      |> send_resp(status, body)
    end)
  end

  defp stub_installation(status \\ 200, json \\ plausible_installed()) do
    stub_installation(fn conn ->
      conn
      |> put_resp_content_type("application/json")
      |> send_resp(status, Jason.encode!(json))
    end)
  end

  defp plausible_installed(bool \\ true, callback_status \\ 202) do
    %{
      "data" => %{
        "completed" => true,
        "snippetsFoundInHead" => 0,
        "snippetsFoundInBody" => 0,
        "plausibleInstalled" => bool,
        "callbackStatus" => callback_status
      }
    }
  end

  defp refute_unhandled(interpretation) do
    refute interpretation.errors == [
             @errors.unknown.message
           ]

    refute interpretation.recommendations == [
             @errors.unknown.recommendation
           ]

    interpretation
  end

  defp assert_error(interpretation, error) do
    refute interpretation.ok?

    assert interpretation.errors == [
             error.message
           ]

    assert interpretation.recommendations == [
             %{text: error.recommendation, url: error.url}
           ]
  end

  defp assert_error(interpretation, error, assigns) do
    recommendation = EEx.eval_string(error.recommendation, assigns: assigns)
    assert_error(interpretation, %{error | recommendation: recommendation})
  end

  defp assert_ok(interpretation) do
    assert interpretation.ok?
    assert interpretation.errors == []
    assert interpretation.recommendations == []
  end
end
