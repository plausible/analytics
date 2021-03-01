defmodule Plausible.Site do
  use Ecto.Schema
  import Ecto.Changeset
  alias Plausible.Auth.User
  alias Plausible.Site.GoogleAuth

  schema "sites" do
    field :domain, :string
    field :timezone, :string
    field :public, :boolean
    field :embeddable, :boolean
    field :external_css, :string

    many_to_many :members, User, join_through: Plausible.Site.Membership
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

  def make_embeddable(site) do
    change(site, embeddable: true)
  end

  def make_not_embeddable(site) do
    change(site, embeddable: false)
  end

  def add_external_css(site, external_css) do
    site
    |> cast(%{external_css: external_css}, [:external_css])
    |> validate_required(:external_css)
    |> validate_format(:external_css, ~r/^https:\/\/.*$/,
      message: "The style sheet must be served as https."
    )
    |> validate_url(:external_css)
  end

  def delete_external_css(site) do
    change(site, external_css: nil)
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

  #  https://gist.github.com/atomkirk/74b39b5b09c7d0f21763dd55b877f998
  defp validate_url(changeset, field, opts \\ []) do
    validate_change(changeset, field, fn _, value ->
      case URI.parse(value) do
        %URI{scheme: nil} ->
          "is missing a scheme (e.g. https)"

        %URI{host: nil} ->
          "is missing a host"

        %URI{host: host} ->
          case :inet.gethostbyname(Kernel.to_charlist(host)) do
            {:ok, _} -> nil
            {:error, _} -> "invalid host"
          end
      end
      |> case do
        error when is_binary(error) -> [{field, Keyword.get(opts, :message, error)}]
        _ -> []
      end
    end)
  end
end
