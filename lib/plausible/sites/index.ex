defmodule Plausible.Sites.Index do
  @moduledoc """
  Site index query module: fetches a sorted, paginated list of site IDs for a
  user, supporting alphanumeric or traffic-based sorting over the last 24 hours.
  """

  import Ecto.Query

  alias Plausible.Auth
  alias Plausible.Repo
  alias Plausible.ClickhouseRepo
  alias Plausible.Site
  alias Plausible.Teams
  alias Plausible.Teams.Sites

  @type sort_by() :: :alnum | :traffic
  @type sort_direction() :: :asc | :desc

  @type list_opt() ::
          {:filter_by_domain, String.t()}
          | {:team, Teams.Team.t() | nil}
          | {:sort_by, sort_by()}
          | {:sort_direction, sort_direction()}

  defmodule Page do
    @moduledoc """
    A single page of results, drop-in replacement for Scrivener.Page 
    """

    @type t() :: %__MODULE__{
            entries: [pos_integer()],
            page_number: pos_integer(),
            page_size: pos_integer(),
            total_entries: non_neg_integer(),
            total_pages: pos_integer()
          }

    @enforce_keys [:entries, :page_number, :page_size, :total_entries, :total_pages]
    defstruct [:entries, :page_number, :page_size, :total_entries, :total_pages]
  end

  defmodule State do
    @moduledoc """
    In-memory representation of a fully-sorted site index for one user
    """

    @type t() :: %__MODULE__{
            user: Auth.User.t(),
            opts: %{filter_by_domain: String.t() | nil, team: Plausible.Teams.Team.t() | nil},
            ordered_ids: [pos_integer()],
            pins: %{pos_integer() => NaiveDateTime.t() | nil},
            domains: %{pos_integer() => String.t()},
            traffic: %{pos_integer() => non_neg_integer()},
            sort_by: Plausible.Sites.Index.sort_by(),
            sort_direction: Plausible.Sites.Index.sort_direction()
          }

    @enforce_keys [:user, :opts, :ordered_ids, :pins, :sort_by, :sort_direction]
    defstruct [
      :user,
      :opts,
      :ordered_ids,
      :pins,
      :sort_by,
      :sort_direction,
      domains: %{},
      traffic: %{}
    ]
  end

  @doc """
  Builds an `Index.State` for `user` by running all necessary queries
  """
  @spec build(Auth.User.t(), [list_opt()]) :: State.t()
  def build(user, opts \\ []) do
    sort_by = Keyword.get(opts, :sort_by, :alnum)
    sort_direction = Keyword.get(opts, :sort_direction, :asc)

    # Fetch the full unfiltered set for the team; domain filtering is applied
    # locally from here on so filter/2 never needs to hit the database.
    site_ids = fetch_site_ids(user, Keyword.delete(opts, :filter_by_domain))
    pins = fetch_pins(user, site_ids)
    domains = fetch_domains(site_ids)

    %State{
      user: user,
      opts: %{
        filter_by_domain: Keyword.get(opts, :filter_by_domain),
        team: Keyword.get(opts, :team)
      },
      ordered_ids: site_ids,
      pins: pins,
      domains: domains,
      traffic: %{},
      sort_by: sort_by,
      sort_direction: sort_direction
    }
    |> sort(opts)
  end

  @spec paginate(
          State.t(),
          page :: pos_integer() | String.t() | nil,
          page_size :: pos_integer() | String.t() | nil
        ) :: Page.t()
  def paginate(%State{ordered_ids: ordered_ids} = state, raw_page_number, raw_page_size) do
    page_number = cast_int(raw_page_number, min: 1, max: :unlimited, default: 1)
    page_size = cast_int(raw_page_size, min: 1, max: 100, default: 24)

    filtered_ids = apply_domain_filter(ordered_ids, state.domains, state.opts.filter_by_domain)

    total_entries = length(filtered_ids)
    total_pages = max(1, ceil(total_entries / page_size))
    page_number = min(page_number, total_pages)

    entries =
      filtered_ids
      |> Enum.drop((page_number - 1) * page_size)
      |> Enum.take(page_size)

    %Page{
      entries: entries,
      page_number: page_number,
      page_size: page_size,
      total_entries: total_entries,
      total_pages: total_pages
    }
  end

  @spec refresh_pins(State.t()) :: State.t()
  def refresh_pins(
        %State{
          user: user,
          ordered_ids: ordered_ids,
          domains: domains,
          traffic: traffic,
          sort_by: sort_by,
          sort_direction: sort_direction
        } = state
      ) do
    new_pins = fetch_pins(user, ordered_ids)

    new_ordered_ids =
      if sort_by == :traffic do
        sort_by_traffic(ordered_ids, new_pins, traffic, sort_direction)
      else
        sort_alnum(ordered_ids, new_pins, domains, sort_direction)
      end

    %State{state | pins: new_pins, ordered_ids: new_ordered_ids}
  end

  @spec update_state(State.t(), :filter_by_domain, String.t() | nil) :: State.t()
  def update_state(%State{} = state, :filter_by_domain, value) do
    %State{state | opts: %{state.opts | filter_by_domain: value}}
  end

  @spec sort(State.t(), [list_opt()]) :: State.t()
  def sort(%State{} = state, opts) do
    sort_by = Keyword.get(opts, :sort_by, state.sort_by)
    sort_direction = Keyword.get(opts, :sort_direction, state.sort_direction)

    apply_order(state, sort_by, sort_direction)
  end

  # no traffic data yet, fetch
  defp apply_order(%State{traffic: t} = state, :traffic, sort_direction)
       when map_size(t) == 0 do
    fetch_traffic_and_sort(state, sort_direction)
  end

  # same sort_by, flip direction
  defp apply_order(
         %State{sort_by: :traffic, sort_direction: old_direction} = state,
         :traffic,
         new_direction
       )
       when old_direction != new_direction do
    ordered_ids = flip_order(state.ordered_ids, state.pins)

    %State{
      state
      | sort_direction: new_direction,
        ordered_ids: ordered_ids
    }
  end

  # alnum flip
  defp apply_order(
         %State{sort_by: :alnum, sort_direction: old_direction} = state,
         :alnum,
         sort_direction
       )
       when old_direction != sort_direction do
    ordered_ids = flip_order(state.ordered_ids, state.pins)

    %State{
      state
      | sort_direction: sort_direction,
        traffic: %{},
        ordered_ids: ordered_ids
    }
  end

  # alnum
  defp apply_order(%State{} = state, :alnum, sort_direction) do
    ordered_ids = sort_alnum(state.ordered_ids, state.pins, state.domains, sort_direction)

    %State{
      state
      | sort_by: :alnum,
        sort_direction: sort_direction,
        traffic: %{},
        ordered_ids: ordered_ids
    }
  end

  # no-op
  defp apply_order(
         %State{
           sort_by: sort_by,
           sort_direction: sort_direction
         } = state,
         sort_by,
         sort_direction
       ) do
    state
  end

  defp fetch_traffic_and_sort(%State{} = state, sort_direction) do
    traffic_list = traffic_for_site_ids(state.ordered_ids)
    traffic_map = Map.new(traffic_list)
    ordered_ids = sort_by_traffic(state.ordered_ids, state.pins, traffic_map, sort_direction)

    %State{
      state
      | sort_by: :traffic,
        sort_direction: sort_direction,
        traffic: traffic_map,
        ordered_ids: ordered_ids
    }
  end

  defp flip_order(site_ids, pins) do
    {pinned, unpinned} = split_pinned(site_ids, pins)
    pinned ++ Enum.reverse(unpinned)
  end

  @spec fetch_site_ids(Auth.User.t(), [list_opt()]) :: [pos_integer()]
  def fetch_site_ids(user, opts \\ []) do
    team = Keyword.get(opts, :team)
    domain_filter = Keyword.get(opts, :filter_by_domain)

    from(u in subquery(Sites.accessible_by(user, team)),
      inner_join: s in ^Site.regular(),
      on: u.site_id == s.id,
      select: s.id
    )
    |> maybe_filter_by_domain_on_site(domain_filter)
    |> Repo.all()
  end

  @spec traffic_for_site_ids([pos_integer()]) :: [{pos_integer(), non_neg_integer()}]
  def traffic_for_site_ids([]), do: []

  def traffic_for_site_ids(site_ids) do
    now = DateTime.utc_now()
    utc_first_dt = DateTime.shift(now, hour: -24)

    utc_first = DateTime.to_naive(utc_first_dt)
    utc_last = DateTime.to_naive(now)
    utc_first_minus_7d = NaiveDateTime.add(utc_first, -7, :day)

    site_ids
    |> Enum.chunk_every(1_000)
    |> Task.async_stream(
      fn batch ->
        try do
          ClickhouseRepo.all(
            from(s in "sessions_v2",
              where: s.site_id in ^batch,
              where: s.sign == 1,
              where: s.start >= ^utc_first_minus_7d,
              where: s.timestamp >= ^utc_first,
              where: s.start <= ^utc_last,
              group_by: s.site_id,
              select:
                {s.site_id, fragment("toUInt64(round(uniq(?) * any(_sample_factor)))", s.user_id)}
            )
          )
        rescue
          e ->
            Sentry.capture_message("traffic_for_site_ids: batch query failed",
              extra: %{
                first_site_id: List.first(batch),
                last_site_id: List.last(batch),
                batch_size: length(batch),
                error: Exception.message(e)
              }
            )

            []
        end
      end,
      max_concurrency: 4,
      ordered: false
    )
    |> Enum.flat_map(fn {:ok, rows} -> rows end)
  end

  defp fetch_pins(_user, []), do: %{}

  defp fetch_pins(user, site_ids) do
    pinned =
      from(up in Site.UserPreference,
        where: up.user_id == ^user.id and up.site_id in ^site_ids and not is_nil(up.pinned_at),
        select: {up.site_id, up.pinned_at}
      )
      |> Repo.all()
      |> Map.new()

    Map.new(site_ids, fn id -> {id, Map.get(pinned, id)} end)
  end

  defp sort_by_traffic(site_ids, pins, traffic_map, sort_direction) do
    sort_ids(site_ids, pins, &Map.get(traffic_map, &1, 0), sort_direction)
  end

  defp sort_alnum(site_ids, pins, domains, sort_direction) do
    sort_ids(site_ids, pins, &Map.get(domains, &1, ""), sort_direction)
  end

  defp sort_ids(site_ids, pins, key_fn, direction) do
    {pinned, unpinned} = split_pinned(site_ids, pins)
    pinned ++ Enum.sort_by(unpinned, key_fn, direction)
  end

  defp split_pinned(site_ids, pins) do
    {pinned_pairs, unpinned} =
      Enum.split_with(site_ids, fn id -> not is_nil(Map.get(pins, id)) end)

    pinned =
      pinned_pairs
      |> Enum.sort_by(fn id -> pins[id] end, {:desc, NaiveDateTime})

    {pinned, unpinned}
  end

  defp fetch_domains([]), do: %{}

  defp fetch_domains(site_ids) do
    from(s in Site.regular(),
      where: s.id in ^site_ids,
      select: {s.id, s.domain}
    )
    |> Repo.all()
    |> Map.new()
  end

  defp apply_domain_filter(site_ids, _domains, filter)
       when filter in [nil, ""] do
    site_ids
  end

  defp apply_domain_filter(site_ids, domains, filter) when is_binary(filter) do
    needle = String.downcase(filter)

    Enum.filter(site_ids, fn id ->
      String.contains?(String.downcase(Map.get(domains, id, "")), needle)
    end)
  end

  defp maybe_filter_by_domain_on_site(query, domain)
       when byte_size(domain) >= 1 and byte_size(domain) <= 64 do
    from([_u, s] in query, where: ilike(s.domain, ^"%#{domain}%"))
  end

  defp maybe_filter_by_domain_on_site(query, _), do: query

  defp cast_int(value, min: min, max: max, default: default) when is_binary(value) do
    case Integer.parse(value) do
      {int, ""} when int >= min and int <= max -> int
      _ -> default
    end
  end

  defp cast_int(value, min: min, max: max, default: _default)
       when is_integer(value) and value >= min and value <= max do
    value
  end

  defp cast_int(_value, min: _min, max: _max, default: default), do: default
end
