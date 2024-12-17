defmodule PlausibleWeb.ErrorReportControllerTest do
  use PlausibleWeb.ConnCase, async: true
  @moduletag :ee_only

  use Bamboo.Test

  import Phoenix.View
  import Plausible.Test.Support.HTML

  alias PlausibleWeb.Endpoint
  alias PlausibleWeb.ErrorView
  alias PlausibleWeb.EmailView

  describe "building sentry links" do
    test "no dsn configured" do
      assert EmailView.sentry_link("some-trace") == ""
    end

    test "with dsn" do
      sample_dsn = "https://foobarbaz@somehost.example.com/1"

      assert EmailView.sentry_link("some-trace", sample_dsn) ==
               "https://somehost.example.com/organizations/sentry/issues/?query=some-trace"
    end
  end

  describe "Logged in" do
    setup [:create_user, :log_in]

    for error <- ["500", "502", "503", "504"] do
      test "renders the form when sentry metadata present: #{error}", %{user: user} do
        Sentry.put_last_event_id_and_source("some-event-id", :plug)
        action_path = Routes.error_report_path(Endpoint, :submit_error_report)

        assert html =
                 render_to_string(ErrorView, unquote(error) <> ".html", %{
                   current_user: user
                 })

        assert form_exists?(html, action_path)
        assert submit_button(html, "form[action=\"#{action_path}\"]")

        assert element_exists?(
                 html,
                 "input[type=\"hidden\"][name=\"error[trace_id]\"][value=\"some-event-id\"]"
               )
      end
    end

    test "submitting the feedback form for authenticated user", %{conn: conn, user: user} do
      action_path = Routes.error_report_path(Endpoint, :submit_error_report)

      conn =
        post(conn, action_path, %{
          "error" => %{"trace_id" => "some-trace-id", "user_feedback" => "Guiz pls fix"}
        })

      assert html = html_response(conn, 200)
      assert html =~ "Your report has been submitted"

      reply_to = "#{user.name} <#{user.email}>"

      assert_delivered_email_matches(%{
        to: [nil: "bugs@plausible.io"],
        subject: "Feedback to Sentry Trace some-trace-id",
        private: %{
          message_params: %{
            "ReplyTo" => ^reply_to
          }
        }
      })
    end

    test "short feedback is not sent", %{conn: conn} do
      action_path = Routes.error_report_path(Endpoint, :submit_error_report)

      conn =
        post(conn, action_path, %{
          "error" => %{"trace_id" => "some-trace-id", "user_feedback" => "short"}
        })

      assert html = html_response(conn, 200)
      assert html =~ "Your report has been submitted"

      refute_email_delivered_with(%{
        subject: "Feedback to Sentry Trace some-trace-id"
      })
    end

    test "submitting no feedback for authenticated user", %{conn: conn} do
      action_path = Routes.error_report_path(Endpoint, :submit_error_report)

      conn =
        post(conn, action_path, %{
          "error" => %{"trace_id" => "some-trace-id"}
        })

      assert html = html_response(conn, 200)
      assert html =~ "Your report has been submitted"

      refute_email_delivered_with(%{
        subject: "Feedback to Sentry Trace some-trace-id"
      })
    end

    test "email renders properly" do
      assert email = PlausibleWeb.Email.error_report("Alice Bob", "some-trace", "hello world")

      text =
        email
        |> Map.fetch!(:html_body)
        |> Floki.parse_document!()
        |> Floki.text()

      assert text =~ "Reported by: Alice Bob"
      assert text =~ "Sentry trace: some-trace"
      assert text =~ "User feedback:\nhello world"
    end
  end

  describe "Not logged in" do
    test "submitting the feedback form for unauthenticated user", %{conn: conn} do
      action_path = Routes.error_report_path(Endpoint, :submit_error_report)

      conn =
        post(conn, action_path, %{
          "error" => %{"trace_id" => "some-trace-id", "user_feedback" => "Guiz pls fix"}
        })

      assert redirected_to(conn) == "/login"
    end

    for error <- ["500", "502", "503", "504"] do
      test "renders the error page, no form, when sentry metadata absent: #{error}", %{conn: conn} do
        conn =
          conn
          |> bypass_through(PlausibleWeb.Router, [:browser])
          |> get("/")

        assert html = render_to_string(ErrorView, unquote(error) <> ".html", %{conn: conn})
        text = html |> Floki.parse_document!() |> Floki.text()
        assert text =~ "There has been a server error"
        assert text =~ "But don't worry, we're on it!"

        action_path = Routes.error_report_path(Endpoint, :submit_error_report)
        refute form_exists?(html, action_path)
      end
    end
  end
end
