defmodule PlausibleWeb.CaptchaTest do
  use Plausible.DataCase

  import Mox
  setup :verify_on_exit!

  alias PlausibleWeb.Captcha

  describe "mocked payloads" do
    @failure Jason.decode!(
               ~s/{"success":false,"error":{"error_code":"response_invalid","detail":"the response was invalid"}}/
             )
    @success Jason.decode!(~s/{"success":true}/)

    test "returns false for non-success response" do
      expect(
        Plausible.HTTPClient.Mock,
        :post,
        fn "https://global.frcapi.com/api/v2/captcha/siteverify",
           [{"content-type", "application/json"}, {"x-api-key", "scottiger"}],
           %{response: "bad", sitekey: "test"} ->
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
        fn "https://global.frcapi.com/api/v2/captcha/siteverify",
           [{"content-type", "application/json"}, {"x-api-key", "scottiger"}],
           %{response: "good", sitekey: "test"} ->
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
    setup_patch_env(:friendly_captcha, sitekey: nil)

    test "returns true when disabled" do
      assert Captcha.verify("disabled")
    end
  end
end
