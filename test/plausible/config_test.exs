defmodule Plausible.ConfigTest do
  use ExUnit.Case

  describe "mailer" do
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
               tls_cacertfile: CAStore.file_path(),
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
               adapter: Bamboo.SMTPAdapter,
               server: "localhost",
               hostname: "localhost",
               port: "2525",
               username: "neo",
               password: "one",
               tls: :if_available,
               allowed_tls_versions: [:tlsv1, :"tlsv1.1", :"tlsv1.2"],
               tls_cacertfile: CAStore.file_path(),
               ssl: "true",
               retries: "3",
               no_mx_lookups: "true"
             ]
    end

    test "unknown adapter raises" do
      env = {"MAILER_ADAPTER", "Bamboo.FakeAdapter"}

      assert_raise ArgumentError,
                   ~r/Unknown mailer_adapter: "Bamboo.FakeAdapter"/,
                   fn -> runtime_config(env) end
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
