defmodule Plausible.Site do
  use Ecto.Schema
  import Ecto.Changeset
  alias Plausible.Auth.User
  alias Plausible.Site.GoogleAuth

  @derive {Jason.Encoder, only: [:domain, :timezone]}
  schema "sites" do
    field :domain, :string
    field :timezone, :string, default: "Etc/UTC"
    field :public, :boolean

    many_to_many :members, User, join_through: Plausible.Site.Membership
    has_many :memberships, Plausible.Site.Membership
    has_one :google_auth, GoogleAuth
    has_one :weekly_report, Plausible.Site.WeeklyReport
    has_one :monthly_report, Plausible.Site.MonthlyReport
    has_one :custom_domain, Plausible.Site.CustomDomain
    has_one :spike_notification, Plausible.Site.SpikeNotification

    timestamps()
  end

  def changeset(site, attrs \\ %{}) do
    site
    |> cast(attrs, [:domain, :timezone])
    |> validate_required([:domain, :timezone])
    |> validate_format(:domain, ~r/^[a-zA-z0-9\-\.\/\:]*$/,
      message: "only letters, numbers, slashes and period allowed"
    )
    |> unique_constraint(:domain)
    |> clean_domain
  end

  def make_public(site) do
    change(site, public: true)
  end

  def make_private(site) do
    change(site, public: false)
  end

  defp clean_domain(changeset) do
    clean_domain =
      (get_field(changeset, :domain) || "")
      |> String.trim()
      |> String.replace_leading("http://", "")
      |> String.replace_leading("https://", "")
      |> String.replace_leading("www.", "")
      |> String.replace_trailing("/", "")
      |> String.downcase()

    change(changeset, %{
      domain: clean_domain
    })
  end
end
