defmodule PlausibleWeb.EmailView do
  use PlausibleWeb, :view

  def user_salutation(user) do
    String.split(user.name) |> List.first
  end
end
