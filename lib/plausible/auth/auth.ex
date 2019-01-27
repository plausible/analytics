defmodule Plausible.Auth do
  use Plausible.Repo
  alias Plausible.Auth

  def create_user(name, email) do
    %Auth.User{}
    |> Auth.User.changeset(%{name: name, email: email})
    |> Repo.insert
  end

  def find_user_by(opts) do
    Repo.get_by(Auth.User, opts)
  end
end
