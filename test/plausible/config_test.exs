defmodule Plausible.ConfigTest do
  use ExUnit.Case
  import Plausible.ConfigHelpers

  describe "get_bool_from_path_or_env/3" do
    test "parses truthy vars" do
      truthy = ["1", "t", "true", "y", "yes", "on"]

      for var <- truthy do
        env = [{"ENABLE_EMAIL_VERIFICATION", var}]
        config = runtime_config(env)
        assert get_in(config, [:plausible, :selfhost, :enable_email_verification]) == true
      end
    end

    test "parses false vars" do
      falsy = ["0", "f", "false", "n", "no", "off"]

      for var <- falsy do
        env = [{"ENABLE_EMAIL_VERIFICATION", var}]
        config = runtime_config(env)
        assert get_in(config, [:plausible, :selfhost, :enable_email_verification]) == false
      end
    end

    test "supports defaults" do
      put_system_env_undo([{"ENABLE_EMAIL_VERIFICATION", nil}])
      config_dir = "/run/secrets"

      assert get_bool_from_path_or_env(config_dir, "ENABLE_EMAIL_VERIFICATION") == nil
      assert get_bool_from_path_or_env(config_dir, "ENABLE_EMAIL_VERIFICATION", true) == true
      assert get_bool_from_path_or_env(config_dir, "ENABLE_EMAIL_VERIFICATION", false) == false
    end

    test "raises on invalid var" do
      env = [{"ENABLE_EMAIL_VERIFICATION", "YOLO"}]

      assert_raise ArgumentError,
                   "Invalid boolean value: \"YOLO\". Expected one of: 1, 0, t, f, true, false, y, n, yes, no, on, off",
                   fn -> runtime_config(env) end
    end
  end

  describe "mailer" do
    test "mailer email default" do
      env = [{"MAILER_EMAIL", nil}]
      assert get_in(runtime_config(env), [:plausible, :mailer_email]) == "plausible@localhost"
    end

    test "mailer email from base url" do
      env = [{"MAILER_EMAIL", nil}, {"BASE_URL", "https://plausible.example.com:8443"}]

      assert get_in(runtime_config(env), [:plausible, :mailer_email]) ==
               "plausible@plausible.example.com"
    end

    test "mailer email custom" do
      env = [{"MAILER_EMAIL", "custom@mailer.email"}]
      assert get_in(runtime_config(env), [:plausible, :mailer_email]) == "custom@mailer.email"
    end

    test "mailer name" do
      env = [{"MAILER_EMAIL", nil}, {"MAILER_NAME", "John"}]

      assert get_in(runtime_config(env), [:plausible, :mailer_email]) ==
               {"John", "plausible@localhost"}

      env = [{"MAILER_EMAIL", "custom@mailer.email"}, {"MAILER_NAME", "John"}]

      assert get_in(runtime_config(env), [:plausible, :mailer_email]) ==
               {"John", "custom@mailer.email"}
    end

    test "defaults to Bamboo.Mua" do
      env = {"MAILER_ADAPTER", nil}

      assert get_in(runtime_config(env), [:plausible, Plausible.Mailer]) == [
               adapter: Bamboo.Mua,
               ssl: [middlebox_comp_mode: false]
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
               {:ssl, true},
               {:retries, "3"},
               {:no_mx_lookups, true}
             ]
    end

    test "Bamboo.Mua (no config)" do
      env = [{"MAILER_ADAPTER", "Bamboo.Mua"}]

      assert get_in(runtime_config(env), [:plausible, Plausible.Mailer]) == [
               {:adapter, Bamboo.Mua},
               {:ssl, [middlebox_comp_mode: false]}
             ]
    end

    test "Bamboo.Mua (middlebox_comp_mode enabled)" do
      env = [{"MAILER_ADAPTER", "Bamboo.Mua"}, {"SMTP_MIDDLEBOX_COMP_MODE", "true"}]

      assert get_in(runtime_config(env), [:plausible, Plausible.Mailer]) == [
               {:adapter, Bamboo.Mua},
               {:ssl, [middlebox_comp_mode: true]}
             ]
    end

    test "Bamboo.Mua (relay config)" do
      env = [
        {"MAILER_ADAPTER", "Bamboo.Mua"},
        {"SMTP_HOST_ADDR", "localhost"},
        {"SMTP_HOST_PORT", "2525"},
        {"SMTP_USER_NAME", "neo"},
        {"SMTP_USER_PWD", "one"}
      ]

      assert get_in(runtime_config(env), [:plausible, Plausible.Mailer]) == [
               {:adapter, Bamboo.Mua},
               {:ssl, [middlebox_comp_mode: false]},
               {:protocol, :tcp},
               {:relay, "localhost"},
               {:port, 2525},
               {:auth, [username: "neo", password: "one"]}
             ]
    end

    test "Bamboo.Mua (ssl relay config)" do
      env = [
        {"MAILER_ADAPTER", "Bamboo.Mua"},
        {"SMTP_HOST_ADDR", "localhost"},
        {"SMTP_HOST_PORT", "2525"},
        {"SMTP_HOST_SSL_ENABLED", "true"},
        {"SMTP_USER_NAME", "neo"},
        {"SMTP_USER_PWD", "one"}
      ]

      assert get_in(runtime_config(env), [:plausible, Plausible.Mailer]) == [
               {:adapter, Bamboo.Mua},
               {:ssl, [middlebox_comp_mode: false]},
               {:protocol, :ssl},
               {:relay, "localhost"},
               {:port, 2525},
               {:auth, [username: "neo", password: "one"]}
             ]
    end

    test "Bamboo.Mua (port=465 relay config)" do
      env = [
        {"MAILER_ADAPTER", "Bamboo.Mua"},
        {"SMTP_HOST_ADDR", "localhost"},
        {"SMTP_HOST_PORT", "465"},
        {"SMTP_USER_NAME", "neo"},
        {"SMTP_USER_PWD", "one"}
      ]

      assert get_in(runtime_config(env), [:plausible, Plausible.Mailer]) == [
               {:adapter, Bamboo.Mua},
               {:ssl, [middlebox_comp_mode: false]},
               {:protocol, :ssl},
               {:relay, "localhost"},
               {:port, 465},
               {:auth, [username: "neo", password: "one"]}
             ]
    end

    test "Bamboo.Mua (no auth relay config)" do
      env = [
        {"MAILER_ADAPTER", "Bamboo.Mua"},
        {"SMTP_HOST_ADDR", "localhost"},
        {"SMTP_HOST_PORT", "2525"},
        {"SMTP_USER_NAME", nil},
        {"SMTP_USER_PWD", nil}
      ]

      assert get_in(runtime_config(env), [:plausible, Plausible.Mailer]) == [
               adapter: Bamboo.Mua,
               ssl: [middlebox_comp_mode: false],
               protocol: :tcp,
               relay: "localhost",
               port: 2525
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
        {"S3_ENDPOINT", nil},
        {"S3_EXPORTS_BUCKET", nil},
        {"S3_IMPORTS_BUCKET", nil}
      ]

      result =
        try do
          runtime_config(env)
        rescue
          e -> e
        end

      assert %ArgumentError{} = result

      assert Exception.message(result) == """
             Missing S3 configuration. Please set S3_ACCESS_KEY_ID, S3_SECRET_ACCESS_KEY, S3_REGION, S3_ENDPOINT, S3_EXPORTS_BUCKET, S3_IMPORTS_BUCKET environment variable(s):

             \tS3_ACCESS_KEY_ID=AKIAIOSFODNN7EXAMPLE
             \tS3_SECRET_ACCESS_KEY=wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY
             \tS3_REGION=us-east-1
             \tS3_ENDPOINT=https://<ACCOUNT_ID>.r2.cloudflarestorage.com
             \tS3_EXPORTS_BUCKET=my-csv-exports-bucket
             \tS3_IMPORTS_BUCKET=my-csv-imports-bucket
             """
    end

    test "renders only missing env vars" do
      env = [
        {"S3_ACCESS_KEY_ID", "AKIAIOSFODNN7EXAMPLE"},
        {"S3_SECRET_ACCESS_KEY", nil},
        {"S3_REGION", "eu-north-1"},
        {"S3_ENDPOINT", nil},
        {"S3_EXPORTS_BUCKET", "my-exports"},
        {"S3_IMPORTS_BUCKET", nil}
      ]

      result =
        try do
          runtime_config(env)
        rescue
          e -> e
        end

      assert %ArgumentError{} = result

      assert Exception.message(result) == """
             Missing S3 configuration. Please set S3_SECRET_ACCESS_KEY, S3_ENDPOINT, S3_IMPORTS_BUCKET environment variable(s):

             \tS3_SECRET_ACCESS_KEY=wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY
             \tS3_ENDPOINT=https://<ACCOUNT_ID>.r2.cloudflarestorage.com
             \tS3_IMPORTS_BUCKET=my-csv-imports-bucket
             """
    end

    test "works when everything is set" do
      env = [
        {"S3_ACCESS_KEY_ID", "minioadmin"},
        {"S3_SECRET_ACCESS_KEY", "minioadmin"},
        {"S3_REGION", "us-east-1"},
        {"S3_ENDPOINT", "http://localhost:6000"},
        {"S3_EXPORTS_BUCKET", "my-exports"},
        {"S3_IMPORTS_BUCKET", "my-imports"}
      ]

      config = runtime_config(env)

      assert config[:ex_aws] == [
               http_client: Plausible.S3.Client,
               access_key_id: "minioadmin",
               secret_access_key: "minioadmin",
               region: "us-east-1",
               s3: [scheme: "http://", host: "localhost", port: 6000]
             ]

      assert get_in(config, [:plausible, Plausible.S3]) == [
               exports_bucket: "my-exports",
               imports_bucket: "my-imports"
             ]
    end
  end

  describe "storage" do
    setup do
      defaults = [
        # comes from our Dockerfile
        {"DEFAULT_DATA_DIR", "/var/lib/plausible"},
        # needed to exercise Plausible.Geo :cache_dir
        {"MAXMIND_LICENSE_KEY", "abc"}
      ]

      env = fn env -> env ++ defaults end
      {:ok, env: env}
    end

    test "defaults", %{env: env} do
      config = runtime_config(env.([{"PERSISTENT_CACHE_DIR", nil}, {"DATA_DIR", nil}]))

      # exports/imports
      assert get_in(config, [:plausible, :data_dir]) == "/var/lib/plausible"
      # locus (mmdb cache)
      assert get_in(config, [:plausible, Plausible.Geo, :cache_dir]) == "/var/lib/plausible"
      # tzdata (timezones cache)
      assert get_in(config, [:tzdata, :data_dir]) == "/var/lib/plausible/tzdata_data"
      # session transfer
      assert get_in(config, [:plausible, :session_transfer_dir]) == "/var/lib/plausible/sessions"
    end

    test "with only DATA_DIR set", %{env: env} do
      config = runtime_config(env.([{"PERSISTENT_CACHE_DIR", nil}, {"DATA_DIR", "/data"}]))

      # exports/imports
      assert get_in(config, [:plausible, :data_dir]) == "/data"
      # locus (mmdb cache)
      assert get_in(config, [:plausible, Plausible.Geo, :cache_dir]) == "/data"
      # tzdata (timezones cache)
      assert get_in(config, [:tzdata, :data_dir]) == "/data/tzdata_data"
      # session transfer
      assert get_in(config, [:plausible, :session_transfer_dir]) == "/data/sessions"
    end

    test "with only PERSISTENT_CACHE_DIR set", %{env: env} do
      config = runtime_config(env.([{"PERSISTENT_CACHE_DIR", "/cache"}, {"DATA_DIR", nil}]))

      # exports/imports
      assert get_in(config, [:plausible, :data_dir]) == "/cache"
      # locus (mmdb cache)
      assert get_in(config, [:plausible, Plausible.Geo, :cache_dir]) == "/cache"
      # tzdata (timezones cache)
      assert get_in(config, [:tzdata, :data_dir]) == "/cache/tzdata_data"
      # session transfer
      assert get_in(config, [:plausible, :session_transfer_dir]) == "/cache/sessions"
    end

    test "with both DATA_DIR and PERSISTENT_CACHE_DIR set", %{env: env} do
      config = runtime_config(env.([{"PERSISTENT_CACHE_DIR", "/cache"}, {"DATA_DIR", "/data"}]))

      # exports/imports
      assert get_in(config, [:plausible, :data_dir]) == "/data"
      # locus (mmdb cache)
      assert get_in(config, [:plausible, Plausible.Geo, :cache_dir]) == "/cache"
      # tzdata (timezones cache)
      assert get_in(config, [:tzdata, :data_dir]) == "/cache/tzdata_data"
      # session transfer
      assert get_in(config, [:plausible, :session_transfer_dir]) == "/cache/sessions"
    end
  end

  describe "postgres" do
    test "default" do
      env = [{"DATABASE_URL", nil}]
      config = runtime_config(env)

      assert get_in(config, [:plausible, Plausible.Repo]) == [
               url: "postgres://postgres:postgres@plausible_db:5432/plausible_db",
               socket_options: []
             ]
    end

    test "socket_dir in hostname" do
      env = [{"DATABASE_URL", "postgresql://postgres:postgres@%2Frun%2Fpostgresql/plausible_db"}]
      config = runtime_config(env)

      assert get_in(config, [:plausible, Plausible.Repo]) == [
               socket_dir: "/run/postgresql",
               database: "plausible_db",
               username: "postgres",
               password: "postgres"
             ]
    end

    test "socket_dir in query" do
      env = [{"DATABASE_URL", "postgresql:///plausible_db?host=/run/postgresql"}]
      config = runtime_config(env)

      assert get_in(config, [:plausible, Plausible.Repo]) == [
               socket_dir: "/run/postgresql",
               database: "plausible_db"
             ]
    end

    test "socket_dir missing" do
      env = [{"DATABASE_URL", "postgresql:///plausible_db"}]
      assert_raise ArgumentError, ~r/doesn't include host info/, fn -> runtime_config(env) end
    end

    test "custom URL" do
      env = [
        {"DATABASE_URL",
         "postgresql://your_username:your_password@cluster-do-user-1234567-0.db.ondigitalocean.com:25060/defaultdb"}
      ]

      config = runtime_config(env)

      assert get_in(config, [:plausible, Plausible.Repo]) == [
               url:
                 "postgresql://your_username:your_password@cluster-do-user-1234567-0.db.ondigitalocean.com:25060/defaultdb",
               socket_options: []
             ]
    end

    test "DATABASE_CACERTFILE enables SSL" do
      env = [
        {"DATABASE_URL",
         "postgresql://your_username:your_password@cluster-do-user-1234567-0.db.ondigitalocean.com:25060/defaultdb"},
        {"DATABASE_CACERTFILE", "/path/to/cacert.pem"}
      ]

      config = runtime_config(env)

      assert get_in(config, [:plausible, Plausible.Repo]) == [
               url:
                 "postgresql://your_username:your_password@cluster-do-user-1234567-0.db.ondigitalocean.com:25060/defaultdb",
               socket_options: [],
               ssl: [cacertfile: "/path/to/cacert.pem"]
             ]
    end
  end

  describe "extra config" do
    test "no-op when no extra path is set" do
      put_system_env_undo({"EXTRA_CONFIG_PATH", nil})

      assert Config.Reader.read!("rel/overlays/import_extra_config.exs") == []
    end

    test "raises if path is invalid" do
      put_system_env_undo({"EXTRA_CONFIG_PATH", "no-such-file"})

      assert_raise File.Error, ~r/could not read file/, fn ->
        Config.Reader.read!("rel/overlays/import_extra_config.exs")
      end
    end

    @tag :tmp_dir
    test "reads extra config", %{tmp_dir: tmp_dir} do
      extra_config_path = Path.join(tmp_dir, "config.exs")

      File.write!(extra_config_path, """
      import Config

      config :plausible, Plausible.Repo,
        after_connect: {Postgrex, :query!, ["SET search_path TO global_prefix", []]}
      """)

      put_system_env_undo({"EXTRA_CONFIG_PATH", extra_config_path})

      assert Config.Reader.read!("rel/overlays/import_extra_config.exs") == [
               {:plausible,
                [
                  {Plausible.Repo,
                   [after_connect: {Postgrex, :query!, ["SET search_path TO global_prefix", []]}]}
                ]}
             ]
    end
  end

  describe "totp" do
    test "pbkdf2 if not set" do
      env = [
        {"TOTP_VAULT_KEY", nil}
      ]

      config = runtime_config(env)

      assert [vault_key: vault_key] = get_in(config, [:plausible, Plausible.Auth.TOTP])
      assert byte_size(vault_key) == 32

      # make sure it doesn't change between releases
      assert vault_key ==
               "\x95\x9C\x05\x9A\xCD\xE4\xEF\xDDH\xFB\xCA\xD5o\xD1z\xCCTǐ\xBC\"J\xF8:\xFAs\xCA\x0Fo\x10\x9B\x84"
    end

    test "can be Base64-encoded 32 bytes (with padding)" do
      # $ openssl rand -base64 32
      # dx2W6PNd/QIC6IyYVWMEaG2fI8/5WVylryM3mRaOpAo=
      env = [
        {"TOTP_VAULT_KEY", "dx2W6PNd/QIC6IyYVWMEaG2fI8/5WVylryM3mRaOpAo="}
      ]

      config = runtime_config(env)

      assert [vault_key: vault_key] = get_in(config, [:plausible, Plausible.Auth.TOTP])
      assert byte_size(vault_key) == 32
      assert vault_key == Base.decode64!("dx2W6PNd/QIC6IyYVWMEaG2fI8/5WVylryM3mRaOpAo=")
    end

    test "fails on invalid key length" do
      assert_raise ArgumentError, ~r/Got Base64 encoded 31 bytes/, fn ->
        runtime_config(_env = [{"TOTP_VAULT_KEY", Base.encode64(:crypto.strong_rand_bytes(31))}])
      end

      assert_raise ArgumentError, ~r/Got Base64 encoded 33 bytes/, fn ->
        runtime_config(_env = [{"TOTP_VAULT_KEY", Base.encode64(:crypto.strong_rand_bytes(33))}])
      end
    end

    test "fails on invalid encoding" do
      assert_raise ArgumentError,
                   ~r/TOTP_VAULT_KEY must be Base64 encoded/,
                   fn ->
                     runtime_config(
                       _env = [
                         {"TOTP_VAULT_KEY",
                          "openssl" <> Base.encode64(:crypto.strong_rand_bytes(32))}
                       ]
                     )
                   end
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
