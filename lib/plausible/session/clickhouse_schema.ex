defmodule Plausible.ClickhouseSession do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key false
  schema "sessions" do
    field :hostname, :string
    field :domain, :string
    field :user_id, :integer
    field :session_id, :integer

    field :start, :naive_datetime
    field :duration, :integer
    field :is_bounce, :boolean
    field :entry_page, :string
    field :exit_page, :string
    field :pageviews, :integer
    field :events, :integer
    field :sign, :integer

    field :referrer, :string
    field :referrer_source, :string
    field :country_code, :string
    field :screen_size, :string
    field :operating_system, :string
    field :browser, :string
    field :timestamp, :naive_datetime
  end

  def random_uint64() do
    :crypto.strong_rand_bytes(8) |> :binary.decode_unsigned()
  end

  def changeset(session, attrs) do
    session
    |> cast(attrs, [
      :hostname,
      :domain,
      :entry_page,
      :exit_page,
      :referrer,
      :fingerprint,
      :start,
      :length,
      :is_bounce,
      :operating_system,
      :browser,
      :referrer_source,
      :country_code,
      :screen_size
    ])
    |> validate_required([:hostname, :domain, :fingerprint, :is_bounce, :start])
  end
end
