defmodule PlausibleWeb.EmailView do
  use PlausibleWeb, :view

  def user_salutation(user) do
    if user.name do
      String.split(user.name) |> List.first
    else
      ""
    end
  end
end
