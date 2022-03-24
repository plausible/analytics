defmodule Plausible.Site.ImportedData do
  use Ecto.Schema

  embedded_schema do
    field :start_date, :date
    field :end_date, :date
    field :source, :string
    field :status, :string
  end
end

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
    field :locked, :boolean
    field :has_stats, :boolean

    embeds_one :imported_data, Plausible.Site.ImportedData, on_replace: :update

    many_to_many :members, User, join_through: Plausible.Site.Membership
    has_many :memberships, Plausible.Site.Membership
    has_many :invitations, Plausible.Auth.Invitation
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
    |> validate_format(:domain, ~r/^[a-zA-Z0-9\-\.\/\:]*$/,
      message: "only letters, numbers, slashes and period allowed"
    )
    |> unique_constraint(:domain,
      message:
        "This domain has already been taken. Perhaps one of your team members registered it? If that's not the case, please contact support@plausible.io"
    )
    |> clean_domain
  end

  def make_public(site) do
    change(site, public: true)
  end

  def make_private(site) do
    change(site, public: false)
  end

  def set_has_stats(site, has_stats_val) do
    change(site, has_stats: has_stats_val)
  end

  def start_import(site, start_date, end_date, imported_source, status \\ "importing") do
    change(site,
      imported_data: %{
        start_date: start_date,
        end_date: end_date,
        source: imported_source,
        status: status
      }
    )
  end

  def import_success(site) do
    change(site, imported_data: %{status: "ok"})
  end

  def import_failure(site) do
    change(site, imported_data: %{status: "error"})
  end

  def set_imported_source(site, imported_source) do
    change(site,
      imported_data: %Plausible.Site.ImportedData{
        end_date: Timex.today(),
        source: imported_source
      }
    )
  end

  def remove_imported_data(site) do
    change(site, imported_data: nil)
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
