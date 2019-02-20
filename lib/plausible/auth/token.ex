defmodule Plausible.Auth.Token do
  @one_day_in_seconds 30 * 60 * 24

  def sign_login(email) do
    Phoenix.Token.sign(PlausibleWeb.Endpoint, "login", %{email: email})
  end

  def verify_login(token) do
    Phoenix.Token.verify(PlausibleWeb.Endpoint, "login", token, max_age: @one_day_in_seconds)
  end

  def sign_activation(name, email) do
    Phoenix.Token.sign(PlausibleWeb.Endpoint, "activation", %{
      name: name,
      email: email
    })
  end

  def verify_activation(token) do
    Phoenix.Token.verify(PlausibleWeb.Endpoint, "activation", token, max_age: @one_day_in_seconds)
  end
end
