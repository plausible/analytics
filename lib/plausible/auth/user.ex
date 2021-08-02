defimpl Bamboo.Formatter, for: Plausible.Auth.User do
  def format_email_address(user, _opts) do
    {user.name, user.email}
  end
end

defmodule Plausible.Auth.User do
  use Ecto.Schema
  import Ecto.Changeset

  @required [:email, :name, :password, :password_confirmation]
  schema "users" do
    field :email, :string
    field :password_hash
    field :password, :string, virtual: true
    field :password_confirmation, :string, virtual: true
    field :name, :string
    field :last_seen, :naive_datetime
    field :trial_expiry_date, :date
    field :theme, :string
    field :email_verified, :boolean

    has_many :site_memberships, Plausible.Site.Membership
    has_many :sites, through: [:site_memberships, :site]
    has_many :api_keys, Plausible.Auth.ApiKey
    has_one :google_auth, Plausible.Site.GoogleAuth
    has_one :subscription, Plausible.Billing.Subscription

    timestamps()
  end

  def new(attrs \\ %{}) do
    %Plausible.Auth.User{}
    |> cast(attrs, @required)
    |> validate_required(@required)
    |> validate_length(:password, min: 6, message: "has to be at least 6 characters")
    |> validate_length(:password, max: 64, message: "cannot be longer than 64 characters")
    |> validate_confirmation(:password)
    |> hash_password()
    |> change(trial_expiry_date: trial_expiry())
    |> unique_constraint(:email)
  end

  def changeset(user, attrs \\ %{}) do
    user
    |> cast(attrs, [:email, :name, :email_verified, :theme, :trial_expiry_date])
    |> validate_required([:email, :name, :email_verified, :trial_expiry_date])
    |> unique_constraint(:email)
  end

  def set_password(user, password) do
    hash = Plausible.Auth.Password.hash(password)

    user
    |> cast(%{password: password}, [:password])
    |> validate_required(:password)
    |> validate_length(:password, min: 6, message: "has to be at least 6 characters")
    |> cast(%{password_hash: hash}, [:password_hash])
  end

  def hash_password(%{errors: [], changes: changes} = changeset) do
    hash = Plausible.Auth.Password.hash(changes[:password])
    change(changeset, password_hash: hash)
  end

  def hash_password(changeset), do: changeset

  defp trial_expiry() do
    if Application.get_env(:plausible, :is_selfhost) do
      Timex.today() |> Timex.shift(years: 100)
    else
      Timex.today() |> Timex.shift(days: 30)
    end
  end
end
