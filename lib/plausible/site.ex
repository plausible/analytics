defmodule Plausible.Site do
  @moduledoc """
  Site schema
  """
  use Ecto.Schema
  use Plausible
  import Ecto.Changeset
  alias Plausible.Auth.User
  alias Plausible.Site.GoogleAuth

  @type t() :: %__MODULE__{}

  @derive {Jason.Encoder, only: [:domain, :timezone]}
  schema "sites" do
    field :domain, :string
    field :timezone, :string, default: "Etc/UTC"
    field :public, :boolean
    field :locked, :boolean
    field :stats_start_date, :date
    field :native_stats_start_at, :naive_datetime
    field :allowed_event_props, {:array, :string}
    field :conversions_enabled, :boolean, default: true
    field :props_enabled, :boolean, default: true
    field :funnels_enabled, :boolean, default: true

    field :ingest_rate_limit_scale_seconds, :integer, default: 60
    # default is set via changeset/2
    field :ingest_rate_limit_threshold, :integer

    field :domain_changed_from, :string
    field :domain_changed_at, :naive_datetime

    # NOTE: needed by `SiteImports` data migration script
    embeds_one :imported_data, Plausible.Site.ImportedData, on_replace: :update

    # NOTE: new teams relations
    belongs_to :team, Plausible.Teams.Team
    has_many :guest_memberships, Plausible.Teams.GuestMembership
    has_many :guest_invitations, Plausible.Teams.GuestInvitation

    embeds_one :installation_meta, Plausible.Site.InstallationMeta,
      on_replace: :update,
      defaults_to_struct: true

    many_to_many :members, User, join_through: Plausible.Site.Membership
    has_many :memberships, Plausible.Site.Membership
    has_many :invitations, Plausible.Auth.Invitation
    has_many :goals, Plausible.Goal, preload_order: [desc: :id]
    has_many :revenue_goals, Plausible.Goal, where: [currency: {:not, nil}]
    has_one :google_auth, GoogleAuth
    has_one :weekly_report, Plausible.Site.WeeklyReport
    has_one :monthly_report, Plausible.Site.MonthlyReport
    has_one :ownership, Plausible.Site.Membership, where: [role: :owner]
    has_one :owner, through: [:ownership, :user]
    has_one :team_owner, through: [:team, :owner]

    # If `from_cache?` is set, the struct might be incomplete - see `Plausible.Site.Cache`.
    # Use `Plausible.Repo.reload!(cached_site)` to pre-fill missing fields if
    # strictly necessary.
    field :from_cache?, :boolean, virtual: true, default: false

    # Used in the context of paginated sites list to order in relation to
    # user's membership state. Currently it can be either "invitation",
    # "pinned_site" or "site", where invitations are first.
    field :entry_type, :string, virtual: true
    field :pinned_at, :naive_datetime, virtual: true

    # Used for caching imports data for the duration of the whole request
    # to avoid multiple identical fetches. Populated by plugs putting
    # `site` in `assigns`.
    field :import_data_loaded, :boolean, default: false, virtual: true
    field :earliest_import_start_date, :date, virtual: true
    field :latest_import_end_date, :date, virtual: true
    field :complete_import_ids, {:array, :integer}, default: [], virtual: true

    timestamps()
  end

  def new_for_team(team, params) do
    params
    |> new()
    |> put_assoc(:team, team)
  end

  def new(params), do: changeset(%__MODULE__{}, params)

  on_ee do
    @domain_unique_error """
    This domain cannot be registered. Perhaps one of your colleagues registered it? If that's not the case, please contact support@plausible.io
    """
  else
    @domain_unique_error """
    This domain cannot be registered. Perhaps one of your colleagues registered it?
    """
  end

  def changeset(site, attrs \\ %{}) do
    site
    |> cast(attrs, [:domain, :timezone])
    |> clean_domain()
    |> validate_required([:domain, :timezone])
    |> validate_timezone()
    |> validate_domain_format()
    |> validate_domain_reserved_characters()
    |> unique_constraint(:domain,
      message: @domain_unique_error
    )
    |> unique_constraint(:domain,
      name: "domain_change_disallowed",
      message: @domain_unique_error
    )
    |> put_change(
      :ingest_rate_limit_threshold,
      Application.get_env(:plausible, __MODULE__)[:default_ingest_threshold]
    )
  end

  def update_changeset(site, attrs \\ %{}, opts \\ []) do
    at =
      opts
      |> Keyword.get(:at, NaiveDateTime.utc_now())
      |> NaiveDateTime.truncate(:second)

    site
    |> changeset(attrs)
    |> handle_domain_change(at)
  end

  def crm_changeset(site, attrs) do
    site
    |> cast(attrs, [
      :timezone,
      :public,
      :native_stats_start_at,
      :ingest_rate_limit_threshold,
      :ingest_rate_limit_scale_seconds
    ])
    |> validate_required([:timezone, :public])
    |> validate_number(:ingest_rate_limit_scale_seconds,
      greater_than_or_equal_to: 1,
      message: "must be at least 1 second"
    )
    |> validate_number(:ingest_rate_limit_threshold,
      greater_than_or_equal_to: 0,
      message: "must be empty, zero or positive"
    )
  end

  def tz_offset(site, utc_now \\ DateTime.utc_now()) do
    case DateTime.shift_zone(utc_now, site.timezone) do
      {:ok, datetime} ->
        datetime.utc_offset + datetime.std_offset

      res ->
        Sentry.capture_message("Unable to determine timezone offset for",
          extra: %{site: site, result: res}
        )

        0
    end
  end

  def make_public(site) do
    change(site, public: true)
  end

  def make_private(site) do
    change(site, public: false)
  end

  def set_stats_start_date(site, val) do
    change(site, stats_start_date: val)
  end

  def set_native_stats_start_at(site, val) do
    change(site, native_stats_start_at: val)
  end

  defp clean_domain(changeset) do
    clean_domain =
      (get_field(changeset, :domain) || "")
      |> String.downcase()
      |> String.trim()
      |> String.replace_leading("http://", "")
      |> String.replace_leading("https://", "")
      |> String.trim("/")
      |> String.replace_leading("www.", "")

    change(changeset, %{domain: clean_domain})
  end

  # https://tools.ietf.org/html/rfc3986#section-2.2
  @uri_reserved_chars ~w(: ? # [ ] @ ! $ & ' \( \) * + , ; =)
  defp validate_domain_reserved_characters(changeset) do
    domain = get_field(changeset, :domain) || ""

    if String.contains?(domain, @uri_reserved_chars) do
      add_error(
        changeset,
        :domain,
        "must not contain URI reserved characters #{@uri_reserved_chars}"
      )
    else
      changeset
    end
  end

  defp validate_domain_format(changeset) do
    validate_format(changeset, :domain, ~r/^[-\.\\\/:\p{L}\d]*$/u,
      message: "only letters, numbers, slashes and period allowed"
    )
  end

  defp handle_domain_change(changeset, at) do
    new_domain = get_change(changeset, :domain)

    if new_domain do
      changeset
      |> put_change(:domain_changed_from, changeset.data.domain)
      |> put_change(:domain_changed_at, at)
      |> unique_constraint(:domain,
        name: "domain_change_disallowed",
        message: @domain_unique_error
      )
      |> unique_constraint(:domain_changed_from,
        message: @domain_unique_error
      )
    else
      changeset
    end
  end

  defp validate_timezone(changeset) do
    tz = get_field(changeset, :timezone)

    if Timex.is_valid_timezone?(tz) do
      changeset
    else
      add_error(changeset, :timezone, "is invalid")
    end
  end
end

defimpl FunWithFlags.Actor, for: Plausible.Site do
  def id(%{domain: domain}) do
    "site:#{domain}"
  end
end
