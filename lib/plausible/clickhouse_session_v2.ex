defmodule Plausible.ClickhouseSessionV2 do
  @moduledoc """
  Session schema for when NumericIDs migration is complete
  """
  use Ecto.Schema

  defmodule BoolUInt8 do
    @moduledoc """
    Custom type to cast Bool as UInt8
    """

    use Ecto.Type

    u8 = Ecto.ParameterizedType.init(Ch, type: "UInt8")

    @impl true
    def type, do: unquote(Macro.escape(u8))

    @impl true
    def cast(true), do: {:ok, 1}
    def cast(false), do: {:ok, 0}
    def cast(nil), do: {:ok, 0}

    @impl true
    def load(1), do: {:ok, true}
    def load(0), do: {:ok, false}

    @impl true
    def dump(true), do: {:ok, 1}
    def dump(false), do: {:ok, 0}
    def dump(nil), do: {:ok, 0}
  end

  @primary_key false
  schema "sessions_v2" do
    field :hostname, :string
    field :site_id, Ch, type: "UInt64"
    field :user_id, Ch, type: "UInt64"
    field :session_id, Ch, type: "UInt64"

    field :start, :naive_datetime
    field :duration, Ch, type: "UInt32"
    field :is_bounce, BoolUInt8
    field :entry_page, :string
    field :exit_page, :string
    field :exit_page_hostname, :string
    field :pageviews, Ch, type: "Int32"
    field :events, Ch, type: "Int32"
    field :sign, Ch, type: "Int8"

    field :"entry_meta.key", {:array, :string}
    field :"entry_meta.value", {:array, :string}

    field :utm_medium, :string
    field :utm_source, :string
    field :utm_campaign, :string
    field :utm_content, :string
    field :utm_term, :string
    field :referrer, :string
    field :referrer_source, :string
    field :channel, Ch, type: "LowCardinality(String)"
    field :click_id_source, Ch, type: "LowCardinality(String)"

    field :country_code, Ch, type: "LowCardinality(FixedString(2))"
    field :subdivision1_code, Ch, type: "LowCardinality(String)"
    field :subdivision2_code, Ch, type: "LowCardinality(String)"
    field :city_geoname_id, Ch, type: "UInt32"

    field :screen_size, Ch, type: "LowCardinality(String)"
    field :operating_system, Ch, type: "LowCardinality(String)"
    field :operating_system_version, Ch, type: "LowCardinality(String)"
    field :browser, Ch, type: "LowCardinality(String)"
    field :browser_version, Ch, type: "LowCardinality(String)"
    field :timestamp, :naive_datetime

    field :transferred_from, :string
  end

  def random_uint64() do
    :crypto.strong_rand_bytes(8) |> :binary.decode_unsigned()
  end
end
