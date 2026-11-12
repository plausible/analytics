defmodule Plausible.ApiRequestLog.Entry do
  @moduledoc """
  ClickHouse schema for the `api_request_log` table.
  """
  use Ecto.Schema

  alias Plausible.Auth.ApiKey
  alias Plausible.OAuth.Grant
  alias Plausible.Teams.Team

  @interfaces [:rest, :mcp]
  @plug_request_id_max_bytes 200
  @sane_user_agent_max_bytes 256

  @type t() :: %__MODULE__{}

  @type attrs() :: %{
          timestamp: DateTime.t(),
          team: Team.t(),
          credential: ApiKey.t() | Grant.t(),
          interface: :rest | :mcp,
          operation: String.t(),
          status: non_neg_integer(),
          billable: boolean(),
          request_id: String.t(),
          user_agent: String.t()
        }

  @primary_key false
  schema "api_request_log" do
    # When the request arrived
    field :timestamp, :utc_datetime

    # The team that the request belongs to
    field :team_id, Ch, type: "UInt64"

    # The user who owns the credential
    field :user_id, Ch, type: "UInt64"

    # What the caller authenticated with: `api_key` or `oauth_grant`
    field :credential_type, Ch, type: "LowCardinality(String)"

    # The ID of the credential in Postgres
    field :credential_id, Ch, type: "UInt64"

    # A stable name for the credential used in the UI, e.g. the API key prefix
    # or the OAuth client name
    field :credential_label, :string

    # How the caller talked to us: `rest` or `mcp`
    field :interface, Ch, type: "LowCardinality(String)"

    # What the caller invoked, for example `GET /api/v1/stats/aggregate` or
    # `tools/call list_sites`.
    field :operation, Ch, type: "LowCardinality(String)"

    # The HTTP status of the response
    field :status, Ch, type: "UInt16"

    # Whether the request counts against the team's API quota
    field :billable, :boolean

    # The `x-request-id` response header for correlation and search purposes,
    # truncated to 200 bytes of valid UTF-8
    field :request_id, :string

    # The `user-agent` request header, truncated to 256 bytes of valid UTF-8
    field :user_agent, :string
  end

  @spec new(attrs()) :: t()
  def new(%{interface: interface} = attrs) when interface in @interfaces do
    {credential_type, credential_label} = credential(attrs.credential)

    %__MODULE__{
      timestamp: attrs.timestamp,
      team_id: attrs.team.id,
      user_id: attrs.credential.user_id,
      credential_type: credential_type,
      credential_id: attrs.credential.id,
      credential_label: credential_label,
      interface: Atom.to_string(interface),
      operation: attrs.operation,
      status: attrs.status,
      billable: attrs.billable,
      request_id: truncate_utf8(attrs.request_id, @plug_request_id_max_bytes),
      user_agent: truncate_utf8(attrs.user_agent, @sane_user_agent_max_bytes)
    }
  end

  defp truncate_utf8(string, max_bytes) do
    string
    |> binary_slice(0, max_bytes)
    |> String.replace_invalid("")
  end

  defp credential(%ApiKey{key_prefix: key_prefix}), do: {"api_key", key_prefix}
  defp credential(%Grant{} = grant), do: {"oauth_grant", Grant.label(grant)}
end
