defmodule PlausibleWeb.CaptchaTest do
  use Plausible.DataCase

  import Mox
  setup :verify_on_exit!

  alias PlausibleWeb.Captcha

  describe "mocked payloads" do
    @failure Jason.decode!(~s/{"success":false,"error-codes":["invalid-input-response"]}/)
    @success Jason.decode!(~s/{"success":true}/)

    test "returns false for non-success response" do
      expect(
        Plausible.HTTPClient.Mock,
        :post,
        fn "https://hcaptcha.com/siteverify",
           [{"content-type", "application/x-www-form-urlencoded"}],
           %{response: "bad", secret: "scottiger"} ->
          {:ok,
           %Finch.Response{
             status: 200,
             headers: [{"content-type", "application/json"}],
             body: @failure
           }}
        end
      )

      refute Captcha.verify("bad")
    end

    test "returns true for successful response" do
      expect(
        Plausible.HTTPClient.Mock,
        :post,
        fn "https://hcaptcha.com/siteverify",
           [{"content-type", "application/x-www-form-urlencoded"}],
           %{response: "good", secret: "scottiger"} ->
          {:ok,
           %Finch.Response{
             status: 200,
             headers: [{"content-type", "application/json"}],
             body: @success
           }}
        end
      )

      assert Captcha.verify("good")
    end
  end

  describe "with patched application env" do
    setup do
      original_env = Application.get_env(:plausible, :hcaptcha)
      Application.put_env(:plausible, :hcaptcha, sitekey: nil)

      on_exit(fn ->
        Application.put_env(:plausible, :hcaptcha, original_env)
      end)
    end

    test "returns true when disabled" do
      assert Captcha.verify("disabled")
    end
  end
end
