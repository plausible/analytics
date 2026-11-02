defmodule Plausible.MailerTest do
  use Plausible.DataCase
  use Bamboo.Test

  describe "from" do
    setup do
      {:ok, user: insert(:user)}
    end

    # see config tests as well
    test "when MAILER_NAME and MAILER_EMAIL", %{user: user} do
      mailer_email = {"John", "custom@mailer.email"}
      patch_env(:mailer_email, mailer_email)

      email = PlausibleWeb.Email.welcome_email(user)
      assert :ok = Plausible.Mailer.send(email)

      assert_delivered_email(email)
      assert email.from == mailer_email
    end

    test "when MAILER_EMAIL", %{user: user} do
      mailer_email = "custom@mailer.email"
      patch_env(:mailer_email, mailer_email)

      email = PlausibleWeb.Email.welcome_email(user)
      assert :ok = Plausible.Mailer.send(email)

      assert_delivered_email(email)
      assert email.from == mailer_email
    end
  end

  describe "suppression" do
    @describetag :ee_only
    @describetag :capture_log

    test "refuses to send to a suppressed address" do
      user = insert(:user, email: "bounced@example.com")

      {:ok, _} =
        Plausible.EmailSuppressions.create_from_bounce(%{
          email: user.email,
          reason: :hard_bounce,
          source: :webhook
        })

      email = PlausibleWeb.Email.welcome_email(user)
      assert {:error, :suppressed} = Plausible.Mailer.send(email)

      refute_delivered_email(email)
    end

    test "refuses to send even when the outgoing address's case differs from how it's stored" do
      {:ok, _} =
        Plausible.EmailSuppressions.create_from_bounce(%{
          email: "downcased@example.com",
          reason: :hard_bounce,
          source: :webhook
        })

      user = insert(:user, email: "Downcased@Example.com")

      email = PlausibleWeb.Email.welcome_email(user)
      assert {:error, :suppressed} = Plausible.Mailer.send(email)

      refute_delivered_email(email)
    end

    test "sends normally once the address is no longer suppressed" do
      user = insert(:user, email: "reactivated@example.com")
      reviewer = insert(:user)

      {:ok, _} =
        Plausible.EmailSuppressions.create_from_bounce(%{
          email: user.email,
          reason: :hard_bounce,
          source: :webhook
        })

      Req.Test.stub(Plausible.Postmark, fn conn ->
        Req.Test.json(conn, %{"Suppressions" => [%{"Status" => "Deleted"}]})
      end)

      {:ok, _} = Plausible.EmailSuppressions.reactivate(user.email, reviewer)

      email = PlausibleWeb.Email.welcome_email(user)
      assert :ok = Plausible.Mailer.send(email)

      assert_delivered_email(email)
    end

    test "still sends priority-stream e-mails to a suppressed address" do
      address = "bounced@example.com"

      {:ok, _} =
        Plausible.EmailSuppressions.create_from_bounce(%{
          email: address,
          reason: :hard_bounce,
          source: :webhook
        })

      email = PlausibleWeb.Email.password_reset_email(address, "http://example.com/reset")
      assert :ok = Plausible.Mailer.send(email)

      assert_delivered_email(email)
    end

    test "does not send a non-priority e-mail to a suppressed address, even alongside a priority one" do
      address = "bounced@example.com"

      {:ok, _} =
        Plausible.EmailSuppressions.create_from_bounce(%{
          email: address,
          reason: :hard_bounce,
          source: :webhook
        })

      base_email = PlausibleWeb.Email.welcome_email(insert(:user, email: address))

      priority_email =
        PlausibleWeb.Email.password_reset_email(address, "http://example.com/reset")

      assert {:error, :suppressed} = Plausible.Mailer.send(base_email)
      assert :ok = Plausible.Mailer.send(priority_email)

      refute_delivered_email(base_email)
      assert_delivered_email(priority_email)
    end

    test "crashes rather than silently under-checking when `to` has more than one address" do
      email =
        Bamboo.Email.new_email(
          from: "from@example.com",
          to: ["one@example.com", "two@example.com"]
        )

      assert_raise RuntimeError, ~r/only supports a single `to` recipient/, fn ->
        Plausible.Mailer.send(email)
      end
    end

    test "crashes rather than silently under-checking when `to` is empty" do
      email = Bamboo.Email.new_email(from: "from@example.com", to: [])

      assert_raise RuntimeError, ~r/only supports a single `to` recipient/, fn ->
        Plausible.Mailer.send(email)
      end
    end
  end

  describe "recording a suppression from a rejected send (Postmark ErrorCode 406)" do
    @describetag :ee_only
    @describetag :capture_log

    setup do
      bypass = Bypass.open()

      original_base_uri = Application.get_env(:bamboo, :postmark_base_uri)
      Application.put_env(:bamboo, :postmark_base_uri, "http://localhost:#{bypass.port}")
      on_exit(fn -> Application.put_env(:bamboo, :postmark_base_uri, original_base_uri) end)

      patch_env(Plausible.Mailer, adapter: Bamboo.PostmarkAdapter, api_key: "test-key")

      %{bypass: bypass}
    end

    test "records a suppression when Postmark actually rejects the send as an inactive recipient",
         %{bypass: bypass} do
      user = insert(:user, email: "ghost@example.com")

      Bypass.expect_once(bypass, "POST", "/email", fn conn ->
        Plug.Conn.resp(
          conn,
          422,
          Jason.encode!(%{
            "ErrorCode" => 406,
            "Message" => "Rejected outright!"
          })
        )
      end)

      email = PlausibleWeb.Email.welcome_email(user)
      assert {:error, :unknown_error} = Plausible.Mailer.send(email)

      assert Plausible.EmailSuppressions.suppressed?("ghost@example.com")

      suppression = Repo.get_by!(Plausible.EmailSuppression, email: "ghost@example.com")
      assert suppression.reason == :recipient_rejected
      assert suppression.source == :rejected
      assert suppression.details =~ "Rejected outright!"
    end

    test "does not record a suppression for an unrelated Postmark error", %{bypass: bypass} do
      user = insert(:user, email: "innocent@example.com")

      Bypass.expect_once(bypass, "POST", "/email", fn conn ->
        Plug.Conn.resp(
          conn,
          422,
          Jason.encode!(%{"ErrorCode" => 300, "Message" => "Invalid email request"})
        )
      end)

      email = PlausibleWeb.Email.welcome_email(user)
      assert {:error, :unknown_error} = Plausible.Mailer.send(email)

      refute Plausible.EmailSuppressions.suppressed?("innocent@example.com")
    end
  end
end
