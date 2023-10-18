defimpl Bamboo.Formatter, for: Plausible.Auth.User do
  def format_email_address(user, _opts) do
    {user.name, user.email}
  end
end

defimpl FunWithFlags.Actor, for: Plausible.Auth.User do
  def id(%{id: id}) do
    "user:#{id}"
  end
end

defmodule Plausible.Auth.User do
  use Ecto.Schema
  import Ecto.Changeset

  @type t() :: %__MODULE__{}

  @required [:email, :name, :password]

  schema "users" do
    field :email, :string
    field :password_hash
    field :password, :string, virtual: true
    field :password_confirmation, :string, virtual: true
    field :name, :string
    field :last_seen, :naive_datetime
    field :trial_expiry_date, :date
    field :theme, Ecto.Enum, values: [:system, :light, :dark]
    field :email_verified, :boolean
    field :previous_email, :string
    embeds_one :grace_period, Plausible.Auth.GracePeriod, on_replace: :update

    has_many :site_memberships, Plausible.Site.Membership
    has_many :sites, through: [:site_memberships, :site]
    has_many :api_keys, Plausible.Auth.ApiKey
    has_one :google_auth, Plausible.Site.GoogleAuth
    has_one :subscription, Plausible.Billing.Subscription
    has_one :enterprise_plan, Plausible.Billing.EnterprisePlan

    timestamps()
  end

  def new(attrs \\ %{}) do
    %Plausible.Auth.User{}
    |> cast(attrs, @required)
    |> validate_required(@required)
    |> validate_length(:password, min: 12, message: "has to be at least 12 characters")
    |> validate_length(:password, max: 128, message: "cannot be longer than 128 characters")
    |> validate_confirmation(:password, required: true)
    |> validate_password_strength()
    |> hash_password()
    |> start_trial
    |> set_email_verified
    |> unique_constraint(:email)
  end

  def settings_changeset(user, attrs \\ %{}) do
    user
    |> cast(attrs, [:email, :name, :theme])
    |> validate_required([:email, :name, :theme])
    |> unique_constraint(:email)
  end

  def email_changeset(user, attrs \\ %{}) do
    user
    |> cast(attrs, [:email, :password])
    |> validate_required([:email, :password])
    |> validate_email_changed()
    |> check_password()
    |> unique_constraint(:email)
    |> set_email_verified()
    |> put_change(:previous_email, user.email)
  end

  def cancel_email_changeset(user) do
    if user.previous_email do
      user
      |> change()
      |> unique_constraint(:email)
      |> put_change(:email_verified, true)
      |> put_change(:email, user.previous_email)
      |> put_change(:previous_email, nil)
    else
      # It shouldn't happen under normal circumstances
      raise "Previous email is empty for user #{user.id} (#{user.email}) when it shouldn't."
    end
  end

  def changeset(user, attrs \\ %{}) do
    user
    |> cast(attrs, [:email, :name, :email_verified, :theme, :trial_expiry_date])
    |> validate_required([:email, :name, :email_verified])
    |> unique_constraint(:email)
  end

  def set_password(user, password) do
    user
    |> cast(%{password: password}, [:password])
    |> validate_required([:password])
    |> validate_length(:password, min: 12, message: "has to be at least 12 characters")
    |> validate_length(:password, max: 128, message: "cannot be longer than 128 characters")
    |> validate_password_strength()
    |> hash_password()
  end

  def hash_password(%{errors: [], changes: changes} = changeset) do
    hash = Plausible.Auth.Password.hash(changes[:password])
    change(changeset, password_hash: hash)
  end

  def hash_password(changeset), do: changeset

  def remove_trial_expiry(user) do
    change(user, trial_expiry_date: nil)
  end

  def start_trial(user) do
    change(user, trial_expiry_date: trial_expiry())
  end

  def end_trial(user) do
    change(user, trial_expiry_date: Timex.today() |> Timex.shift(days: -1))
  end

  def password_strength(changeset) do
    case get_field(changeset, :password) do
      nil ->
        %{suggestions: [], warning: "", score: 0}

      # Passwords past (approximately) 32 characters are treated
      # as strong, despite what they contain, to avoid unnecessarily
      # expensive computation.
      password when byte_size(password) > 32 ->
        %{suggestions: [], warning: "", score: 4}

      password ->
        existing_phrases =
          []
          |> maybe_add_phrase(get_field(changeset, :name))
          |> maybe_add_phrase(get_field(changeset, :email))

        case ZXCVBN.zxcvbn(password, existing_phrases) do
          %{score: score, feedback: feedback} ->
            %{suggestions: feedback.suggestions, warning: feedback.warning, score: score}

          :error ->
            %{suggestions: [], warning: "", score: 3}
        end
    end
  catch
    _kind, _value ->
      %{suggestions: [], warning: "", score: 3}
  end

  def profile_img_url(%__MODULE__{email: email}) do
    hash =
      email
      |> String.trim()
      |> String.downcase()
      |> :erlang.md5()
      |> Base.encode16(case: :lower)

    Path.join(PlausibleWeb.Endpoint.url(), ["avatar/", hash])
  end

  defp validate_email_changed(changeset) do
    if !get_change(changeset, :email) && !changeset.errors[:email] do
      add_error(changeset, :email, "can't be the same", validation: :different_email)
    else
      changeset
    end
  end

  defp check_password(changeset) do
    if password = get_change(changeset, :password) do
      if Plausible.Auth.Password.match?(password, changeset.data.password_hash) do
        changeset
      else
        add_error(changeset, :password, "is invalid", validation: :check_password)
      end
    else
      changeset
    end
  end

  defp validate_password_strength(changeset) do
    if get_change(changeset, :password) != nil and password_strength(changeset).score <= 2 do
      add_error(changeset, :password, "is too weak", validation: :strength)
    else
      changeset
    end
  end

  defp maybe_add_phrase(phrases, nil), do: phrases

  defp maybe_add_phrase(phrases, phrase) do
    parts = String.split(phrase)

    [phrase, parts]
    |> List.flatten(phrases)
    |> Enum.uniq()
  end

  defp trial_expiry() do
    if Application.get_env(:plausible, :is_selfhost) do
      Timex.today() |> Timex.shift(years: 100)
    else
      Timex.today() |> Timex.shift(days: 30)
    end
  end

  defp set_email_verified(user) do
    if Keyword.fetch!(Application.get_env(:plausible, :selfhost), :enable_email_verification) do
      change(user, email_verified: false)
    else
      change(user, email_verified: true)
    end
  end
end
