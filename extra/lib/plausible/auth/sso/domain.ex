defmodule Plausible.Auth.SSO.Domain do
  @moduledoc """
  Once SSO integration is initiated, it's possible to start
  allow-listing domains for it, in parallel with finalizing
  the setup on IdP's end.

  Each pending domain should be periodically checked for
  ownership verification by testing for presence of TXT record, meta tag
  or URL. The moment whichever of them succeeds first, 
  the domain is marked as verified with method and timestamp 
  recorded.
  """

  use Ecto.Schema

  import Ecto.Changeset

  alias Plausible.Auth.SSO

  @type t() :: %__MODULE__{}

  @verification_methods [:dns_txt, :url, :meta_tag]
  @type verification_method() :: unquote(Enum.reduce(@verification_methods, &{:|, [], [&1, &2]}))

  @spec verification_methods() :: list(verification_method())
  def verification_methods(), do: @verification_methods

  use Plausible.Auth.SSO.Domain.Status

  @derive {Plausible.Audit.Encoder,
           only: [:identifier, :domain, :verified_via, :status, :sso_integration],
           allow_not_loaded: [:sso_integration]}

  schema "sso_domains" do
    field :identifier, Ecto.UUID
    field :domain, :string
    field :verified_via, Ecto.Enum, values: @verification_methods
    field :last_verified_at, :naive_datetime

    field :status, Ecto.Enum,
      values: Status.all(),
      default: Status.pending()

    belongs_to :sso_integration, Plausible.Auth.SSO.Integration

    timestamps()
  end

  @spec create_changeset(SSO.Integration.t(), String.t() | nil) :: Ecto.Changeset.t()
  def create_changeset(integration, domain) do
    %__MODULE__{}
    |> cast(%{domain: domain}, [:domain])
    |> validate_required(:domain)
    |> normalize_domain(:domain)
    |> validate_domain(:domain)
    |> unique_constraint(:domain, message: "is already in use")
    |> put_change(:identifier, Ecto.UUID.generate())
    |> put_assoc(:sso_integration, integration)
  end

  @spec verified_changeset(t(), verification_method(), NaiveDateTime.t()) ::
          Ecto.Changeset.t()
  def verified_changeset(sso_domain, method, now) do
    sso_domain
    |> change()
    |> put_change(:verified_via, method)
    |> put_change(:last_verified_at, now)
    |> put_change(:status, Status.verified())
  end

  @spec unverified_changeset(t(), NaiveDateTime.t(), atom()) :: Ecto.Changeset.t()
  def unverified_changeset(sso_domain, now, status \\ Status.in_progress()) do
    sso_domain
    |> change()
    |> put_change(:verified_via, nil)
    |> put_change(:last_verified_at, now)
    |> put_change(:status, status)
  end

  @spec valid_domain?(String.t()) :: boolean()
  def valid_domain?(domain) do
    # This is not a surefire way to ensure the domain is correct,
    # but it should give a bit more confidence that it's at least
    # resolvable.
    case URI.new("https://" <> domain) do
      {:ok, %{host: host, port: port, path: nil, query: nil, fragment: nil, userinfo: nil}}
      when is_binary(host) and port in [80, 443] ->
        true

      _ ->
        false
    end
  end

  defp normalize_domain(changeset, field) do
    if domain = get_change(changeset, field) do
      # We try to clear the usual copy-paste prefixes.
      normalized =
        domain
        |> String.trim()
        |> String.downcase()
        |> String.split("://", parts: 2)
        |> List.last()
        |> String.trim("/")

      case URI.new("https://" <> normalized) do
        {:ok, %{host: host}} when is_binary(host) and host != "" ->
          put_change(changeset, field, host)

        _ ->
          put_change(changeset, field, normalized)
      end
    else
      changeset
    end
  end

  defp validate_domain(changeset, field) do
    if domain = get_change(changeset, field) do
      if valid_domain?(domain) do
        changeset
      else
        add_error(changeset, field, "invalid domain", validation: :domain)
      end
    else
      changeset
    end
  end
end
