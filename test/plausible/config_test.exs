defmodule Plausible.ConfigTest do
  use ExUnit.Case

  describe "mailer" do
    test "mailer email default" do
      env = [{"MAILER_EMAIL", nil}]
      assert get_in(runtime_config(env), [:plausible, :mailer_email]) == "hello@plausible.local"
    end

    test "mailer email custom" do
      env = [{"MAILER_EMAIL", "custom@mailer.email"}]
      assert get_in(runtime_config(env), [:plausible, :mailer_email]) == "custom@mailer.email"
    end

    test "mailer name" do
      env = [{"MAILER_EMAIL", nil}, {"MAILER_NAME", "John"}]

      assert get_in(runtime_config(env), [:plausible, :mailer_email]) ==
               {"John", "hello@plausible.local"}

      env = [{"MAILER_EMAIL", "custom@mailer.email"}, {"MAILER_NAME", "John"}]

      assert get_in(runtime_config(env), [:plausible, :mailer_email]) ==
               {"John", "custom@mailer.email"}
    end

    test "defaults to Bamboo.SMTPAdapter" do
      env = {"MAILER_ADAPTER", nil}

      assert get_in(runtime_config(env), [:plausible, Plausible.Mailer]) == [
               adapter: Bamboo.SMTPAdapter,
               server: "mail",
               hostname: "localhost",
               port: "25",
               username: nil,
               password: nil,
               tls: :if_available,
               allowed_tls_versions: [:tlsv1, :"tlsv1.1", :"tlsv1.2"],
               ssl: false,
               retries: 2,
               no_mx_lookups: true
             ]
    end

    test "Bamboo.PostmarkAdapter" do
      env = [
        {"MAILER_ADAPTER", "Bamboo.PostmarkAdapter"},
        {"POSTMARK_API_KEY", "some-postmark-key"}
      ]

      assert get_in(runtime_config(env), [:plausible, Plausible.Mailer]) == [
               adapter: Bamboo.PostmarkAdapter,
               request_options: [recv_timeout: 10_000],
               api_key: "some-postmark-key"
             ]
    end

    test "Bamboo.MailgunAdapter" do
      env = [
        {"MAILER_ADAPTER", "Bamboo.MailgunAdapter"},
        {"MAILGUN_API_KEY", "some-mailgun-key"},
        {"MAILGUN_DOMAIN", "example.com"}
      ]

      assert get_in(runtime_config(env), [:plausible, Plausible.Mailer]) == [
               adapter: Bamboo.MailgunAdapter,
               hackney_opts: [recv_timeout: 10_000],
               api_key: "some-mailgun-key",
               domain: "example.com"
             ]
    end

    test "Bamboo.MailgunAdapter with custom MAILGUN_BASE_URI" do
      env = [
        {"MAILER_ADAPTER", "Bamboo.MailgunAdapter"},
        {"MAILGUN_API_KEY", "some-mailgun-key"},
        {"MAILGUN_DOMAIN", "example.com"},
        {"MAILGUN_BASE_URI", "https://api.eu.mailgun.net/v3"}
      ]

      assert get_in(runtime_config(env), [:plausible, Plausible.Mailer]) == [
               adapter: Bamboo.MailgunAdapter,
               hackney_opts: [recv_timeout: 10_000],
               api_key: "some-mailgun-key",
               domain: "example.com",
               base_uri: "https://api.eu.mailgun.net/v3"
             ]
    end

    test "Bamboo.MandrillAdapter" do
      env = [
        {"MAILER_ADAPTER", "Bamboo.MandrillAdapter"},
        {"MANDRILL_API_KEY", "some-mandrill-key"}
      ]

      assert get_in(runtime_config(env), [:plausible, Plausible.Mailer]) == [
               adapter: Bamboo.MandrillAdapter,
               hackney_opts: [recv_timeout: 10_000],
               api_key: "some-mandrill-key"
             ]
    end

    test "Bamboo.SendGridAdapter" do
      env = [
        {"MAILER_ADAPTER", "Bamboo.SendGridAdapter"},
        {"SENDGRID_API_KEY", "some-sendgrid-key"}
      ]

      assert get_in(runtime_config(env), [:plausible, Plausible.Mailer]) == [
               adapter: Bamboo.SendGridAdapter,
               hackney_opts: [recv_timeout: 10_000],
               api_key: "some-sendgrid-key"
             ]
    end

    test "Bamboo.SMTPAdapter" do
      env = [
        {"MAILER_ADAPTER", "Bamboo.SMTPAdapter"},
        {"SMTP_HOST_ADDR", "localhost"},
        {"SMTP_HOST_PORT", "2525"},
        {"SMTP_USER_NAME", "neo"},
        {"SMTP_USER_PWD", "one"},
        {"SMTP_HOST_SSL_ENABLED", "true"},
        {"SMTP_RETRIES", "3"},
        {"SMTP_MX_LOOKUPS_ENABLED", "true"}
      ]

      assert get_in(runtime_config(env), [:plausible, Plausible.Mailer]) == [
               {:adapter, Bamboo.SMTPAdapter},
               {:server, "localhost"},
               {:hostname, "localhost"},
               {:port, "2525"},
               {:username, "neo"},
               {:password, "one"},
               {:tls, :if_available},
               {:allowed_tls_versions, [:tlsv1, :"tlsv1.1", :"tlsv1.2"]},
               {:ssl, "true"},
               {:retries, "3"},
               {:no_mx_lookups, "true"}
             ]
    end

    test "unknown adapter raises" do
      env = {"MAILER_ADAPTER", "Bamboo.FakeAdapter"}

      assert_raise ArgumentError,
                   ~r/Unknown mailer_adapter: "Bamboo.FakeAdapter"/,
                   fn -> runtime_config(env) end
    end
  end

  describe "log_failed_login_attempts" do
    test "can be true" do
      env = {"LOG_FAILED_LOGIN_ATTEMPTS", "true"}
      assert get_in(runtime_config(env), [:plausible, :log_failed_login_attempts]) == true
    end

    test "can be false" do
      env = {"LOG_FAILED_LOGIN_ATTEMPTS", "false"}
      assert get_in(runtime_config(env), [:plausible, :log_failed_login_attempts]) == false
    end

    test "is false by default" do
      env = {"LOG_FAILED_LOGIN_ATTEMPTS", nil}
      assert get_in(runtime_config(env), [:plausible, :log_failed_login_attempts]) == false
    end
  end

  describe "s3" do
    test "has required env vars" do
      env = [
        {"S3_ACCESS_KEY_ID", nil},
        {"S3_SECRET_ACCESS_KEY", nil},
        {"S3_REGION", nil},
        {"S3_ENDPOINT", nil}
      ]

      result =
        try do
          runtime_config(env)
        rescue
          e -> e
        end

      assert %ArgumentError{} = result

      assert Exception.message(result) == """
             Missing S3 configuration. Please set S3_ACCESS_KEY_ID, S3_SECRET_ACCESS_KEY, S3_REGION, S3_ENDPOINT environment variable(s):

             \tS3_ACCESS_KEY_ID=AKIAIOSFODNN7EXAMPLE
             \tS3_SECRET_ACCESS_KEY=wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY
             \tS3_REGION=us-east-1
             \tS3_ENDPOINT=https://<ACCOUNT_ID>.r2.cloudflarestorage.com
             """
    end

    test "renders only missing env vars" do
      env = [
        {"S3_ACCESS_KEY_ID", "AKIAIOSFODNN7EXAMPLE"},
        {"S3_SECRET_ACCESS_KEY", nil},
        {"S3_REGION", "eu-north-1"},
        {"S3_ENDPOINT", nil}
      ]

      result =
        try do
          runtime_config(env)
        rescue
          e -> e
        end

      assert %ArgumentError{} = result

      assert Exception.message(result) == """
             Missing S3 configuration. Please set S3_SECRET_ACCESS_KEY, S3_ENDPOINT environment variable(s):

             \tS3_SECRET_ACCESS_KEY=wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY
             \tS3_ENDPOINT=https://<ACCOUNT_ID>.r2.cloudflarestorage.com
             """
    end

    test "works when everything is set" do
      env = [
        {"S3_ACCESS_KEY_ID", "minioadmin"},
        {"S3_SECRET_ACCESS_KEY", "minioadmin"},
        {"S3_REGION", "us-east-1"},
        {"S3_ENDPOINT", "http://localhost:6000"}
      ]

      config = runtime_config(env)

      assert config[:ex_aws] == [
               http_client: Plausible.S3.Client,
               access_key_id: "minioadmin",
               secret_access_key: "minioadmin",
               region: "us-east-1",
               s3: [scheme: "http://", host: "localhost", port: 6000]
             ]
    end
  end

  defp runtime_config(env) do
    put_system_env_undo(env)
    Config.Reader.read!("config/runtime.exs", env: :prod)
  end

  defp put_system_env_undo(env) do
    before = System.get_env()

    {to_delete, to_put} = Enum.split_with(List.wrap(env), fn {_, v} -> is_nil(v) end)
    Enum.each(to_delete, fn {k, _} -> System.delete_env(k) end)
    System.put_env(to_put)

    on_exit(fn ->
      Enum.each(System.get_env(), fn {k, _} -> System.delete_env(k) end)
      System.put_env(before)
    end)
  end
end
