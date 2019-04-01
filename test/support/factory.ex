defmodule Plausible.Factory do
  use ExMachina.Ecto, repo: Plausible.Repo

  def user_factory(attrs) do
    pw = Map.get(attrs, :password, "password")

    user = %Plausible.Auth.User{
      name: "Jane Smith",
      email: sequence(:email, &"email-#{&1}@example.com"),
      password_hash: Plausible.Auth.Password.hash(pw)
    }

    merge_attributes(user, attrs)
  end

  def site_factory do
    domain = sequence(:domain, &"example-#{&1}.com")

    %Plausible.Site{
      domain: domain,
      timezone: "UTC",
    }
  end

  def pageview_factory do
    hostname = sequence(:domain, &"example-#{&1}.com")
    user_id = sequence(:user_id, &"uid-#{&1}")
    session_id = sequence(:session_id, &"sid-#{&1}")

    %Plausible.Pageview{
      hostname: hostname,
      pathname: "/",
      new_visitor: true,
      user_id: user_id,
      session_id: session_id
    }
  end
end
