defmodule Plausible.Auth.Token do
  @one_hour_in_seconds 30 * 60

  def sign_password_reset(email) do
    Phoenix.Token.sign(PlausibleWeb.Endpoint, "password-reset", %{email: email})
  end

  def verify_password_reset(token) do
    Phoenix.Token.verify(PlausibleWeb.Endpoint, "password-reset", token,
      max_age: @one_hour_in_seconds
    )
  end
end
