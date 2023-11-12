defmodule Plausible.Export do
  @moduledoc "Exports Plausible data for events and sessions."

  import Ecto.Query
  import Bitwise

  # TODO sampling
  # TODO do in one pass over both tables?
  # TODO scheduling (limit parallel exports)

  @spec export_queries(pos_integer) :: %{atom => Ecto.Query.t()}
  def export_queries(site_id) do
    %{
      visitors: export_visitors_q(site_id),
      sources: export_sources_q(site_id),
      pages: export_pages_q(site_id),
      entry_pages: export_entry_pages_q(site_id),
      exit_pages: export_exit_pages_q(site_id),
      locations: export_locations_q(site_id),
      devices: export_devices_q(site_id),
      browsers: export_browsers_q(site_id),
      operating_systems: export_operating_systems_q(site_id)
    }
  end

  defmacrop date(timestamp) do
    quote do
      selected_as(fragment("toDate(?)", unquote(timestamp)), :date)
    end
  end

  defmacrop visit_duration(t) do
    quote do
      selected_as(
        fragment(
          "toUInt32(round(?))",
          sum(unquote(t).sign * unquote(t).duration) / sum(unquote(t).sign)
        ),
        :visit_duration
      )
    end
  end

  defmacrop visitors(t) do
    quote do
      selected_as(fragment("uniq(?)", unquote(t).user_id), :visitors)
    end
  end

  defmacrop visits(t) do
    quote do
      selected_as(sum(unquote(t).sign), :visits)
    end
  end

  defmacrop bounces(t) do
    quote do
      selected_as(sum(unquote(t).sign * unquote(t).is_bounce), :bounces)
    end
  end

  @spec export_visitors_q(pos_integer) :: Ecto.Query.t()
  def export_visitors_q(site_id) do
    visitors_sessions_q =
      from s in "sessions_v2",
        where: s.site_id == ^site_id,
        group_by: selected_as(:date),
        select: %{
          date: date(s.start),
          bounces: bounces(s),
          visits: visits(s),
          visit_duration: visit_duration(s)
        }

    visitors_events_q =
      from e in "events_v2",
        where: e.site_id == ^site_id,
        group_by: selected_as(:date),
        select: %{
          date: date(e.timestamp),
          visitors: visitors(e),
          pageviews: selected_as(fragment("countIf(?='pageview')", e.name), :pageviews)
        }

    visitors_q =
      "e"
      |> with_cte("e", as: ^visitors_events_q)
      |> with_cte("s", as: ^visitors_sessions_q)

    from e in visitors_q,
      full_join: s in "s",
      on: e.date == s.date,
      order_by: selected_as(:date),
      select: [
        # TODO can use coalesce?
        selected_as(fragment("greatest(?,?)", s.date, e.date), :date),
        e.visitors,
        e.pageviews,
        s.bounces,
        s.visits,
        s.visit_duration
      ]
  end

  @spec export_sources_q(pos_integer) :: Ecto.Query.t()
  def export_sources_q(site_id) do
    from s in "sessions_v2",
      where: s.site_id == ^site_id,
      group_by: [
        selected_as(:date),
        s.utm_source,
        s.utm_campaign,
        s.utm_medium,
        s.utm_content,
        s.utm_term
      ],
      order_by: selected_as(:date),
      select: [
        date(s.start),
        selected_as(s.utm_source, :source),
        s.utm_campaign,
        s.utm_content,
        s.utm_term,
        visitors(s),
        visits(s),
        visit_duration(s),
        bounces(s)
      ]
  end

  @spec export_pages_q(pos_integer) :: Ecto.Query.t()
  def export_pages_q(site_id) do
    window_q =
      from e in "events_v2",
        where: e.site_id == ^site_id,
        select: %{
          timestamp: e.timestamp,
          next_timestamp:
            over(fragment("leadInFrame(?)", e.timestamp),
              partition_by: e.session_id,
              order_by: e.timestamp,
              frame: fragment("ROWS BETWEEN CURRENT ROW AND 1 FOLLOWING")
            ),
          pathname: e.pathname,
          hostname: e.hostname,
          name: e.name,
          user_id: e.user_id
        }

    # TODO exits > pageviews?
    from e in subquery(window_q),
      group_by: [selected_as(:date), e.pathname],
      order_by: selected_as(:date),
      select: [
        date(e.timestamp),
        selected_as(e.pathname, :path),
        selected_as(fragment("any(?)", e.hostname), :hostname),
        selected_as(
          fragment("sum(greatest(?,0))", e.next_timestamp - e.timestamp),
          :time_on_page
        ),
        selected_as(fragment("countIf(?=0)", e.next_timestamp), :exits),
        selected_as(fragment("countIf(?='pageview')", e.name), :pageviews),
        visitors(e)
      ]
  end

  @spec export_entry_pages_q(pos_integer) :: Ecto.Query.t()
  def export_entry_pages_q(site_id) do
    from s in "sessions_v2",
      where: s.site_id == ^site_id,
      group_by: [selected_as(:date), s.entry_page],
      order_by: selected_as(:date),
      select: [
        date(s.start),
        s.entry_page,
        visitors(s),
        selected_as(sum(s.sign), :entrances),
        visit_duration(s),
        bounces(s)
      ]
  end

  @spec export_exit_pages_q(pos_integer) :: Ecto.Query.t()
  def export_exit_pages_q(site_id) do
    from s in "sessions_v2",
      where: s.site_id == ^site_id,
      group_by: [selected_as(:date), s.exit_page],
      order_by: selected_as(:date),
      select: [
        date(s.start),
        s.exit_page,
        visitors(s),
        selected_as(sum(s.sign), :exits)
      ]
  end

  @spec export_locations_q(pos_integer) :: Ecto.Query.t()
  def export_locations_q(site_id) do
    from s in "sessions_v2",
      where: s.site_id == ^site_id,
      group_by: [selected_as(:date), s.country_code, selected_as(:region), s.city_geoname_id],
      order_by: selected_as(:date),
      select: [
        date(s.start),
        selected_as(s.country_code, :country),
        # TODO avoid "AK-", "-US", "-"
        selected_as(
          fragment("concatWithSeparator('-',?,?)", s.subdivision1_code, s.subdivision2_code),
          :region
        ),
        selected_as(s.city_geoname_id, :city),
        visitors(s),
        visits(s),
        visit_duration(s),
        bounces(s)
      ]
  end

  @spec export_devices_q(pos_integer) :: Ecto.Query.t()
  def export_devices_q(site_id) do
    from s in "sessions_v2",
      where: s.site_id == ^site_id,
      group_by: [selected_as(:date), s.screen_size],
      order_by: selected_as(:date),
      select: [
        date(s.start),
        selected_as(s.screen_size, :device),
        visitors(s),
        visits(s),
        visit_duration(s),
        bounces(s)
      ]
  end

  @spec export_browsers_q(pos_integer) :: Ecto.Query.t()
  def export_browsers_q(site_id) do
    from s in "sessions_v2",
      where: s.site_id == ^site_id,
      group_by: [selected_as(:date), s.browser],
      order_by: selected_as(:date),
      select: [
        date(s.start),
        s.browser,
        visitors(s),
        visits(s),
        visit_duration(s),
        bounces(s)
      ]
  end

  @spec export_operating_systems_q(pos_integer) :: Ecto.Query.t()
  def export_operating_systems_q(site_id) do
    from s in "sessions_v2",
      where: s.site_id == ^site_id,
      group_by: [selected_as(:date), s.operating_system],
      order_by: selected_as(:date),
      select: [
        date(s.start),
        s.operating_system,
        visitors(s),
        visits(s),
        visit_duration(s),
        bounces(s)
      ]
  end

  @spec export_archive(
          DBConnection.conn(),
          queries :: [{name, sql :: iodata, params :: [term]} | {name, query :: Ecto.Query.t()}],
          on_data_acc,
          on_data :: (iodata, on_data_acc -> {:ok, on_data_acc}),
          opts :: Keyword.t()
        ) :: {:ok, on_data_acc}
        when name: String.t(), on_data_acc: term
  def export_archive(conn, queries, on_data_acc, on_data, opts \\ []) do
    {metadata_entry, encoded} = zip_start_entry("metadata.json")
    {:ok, on_data_acc} = on_data.(encoded, on_data_acc)

    metadata =
      Jason.encode_to_iodata!(%{
        "version" => "0",
        "format" => Keyword.fetch!(opts, :format),
        "domain" => Keyword.fetch!(opts, :domain)
      })

    {:ok, on_data_acc} = on_data.(metadata, on_data_acc)
    metadata_entry = zip_grow_entry(metadata_entry, metadata)
    {metadata_entry, encoded} = zip_end_entry(metadata_entry)
    {:ok, on_data_acc} = on_data.(encoded, on_data_acc)

    raw_queries =
      Enum.map(queries, fn query ->
        case query do
          {name, query} ->
            {sql, params} = Plausible.ClickhouseRepo.to_sql(:all, query)
            {name, sql, params}

          {_name, _sql, _params} = ready ->
            ready
        end
      end)

    {entries, on_data_acc} =
      Enum.reduce(raw_queries, {[], on_data_acc}, fn {name, sql, params},
                                                     {entries, on_data_acc} ->
        Ch.run(conn, fn conn ->
          packets = Ch.stream(conn, sql, params, opts)
          {entry, encoded} = zip_start_entry(name)
          {:ok, on_data_acc} = on_data.(encoded, on_data_acc)

          {entry, on_data_acc} =
            Enum.reduce(packets, {entry, on_data_acc}, fn packets, acc ->
              Enum.reduce(packets, acc, fn packet, {entry, on_data_acc} ->
                case packet do
                  {:data, _ref, data} ->
                    {:ok, on_data_acc} = on_data.(data, on_data_acc)
                    {zip_grow_entry(entry, data), on_data_acc}

                  _other ->
                    {entry, on_data_acc}
                end
              end)
            end)

          {entry, encoded} = zip_end_entry(entry)
          {:ok, on_data_acc} = on_data.(encoded, on_data_acc)
          {[entry | entries], on_data_acc}
        end)
      end)

    {:ok, _on_data_acc} =
      on_data.(
        zip_encode_central_directory([metadata_entry | :lists.reverse(entries)]),
        on_data_acc
      )
  end

  @spec zip_start_entry(String.t(), Keyword.t()) :: {zip_entry :: map, iodata}
  defp zip_start_entry(name, opts \\ []) do
    mtime = NaiveDateTime.from_erl!(:calendar.local_time())
    nsize = byte_size(name)
    compression = opts[:compression] || 0

    # see 4.4 in https://pkware.cachefly.net/webdocs/casestudies/APPNOTE.TXT
    local_header = <<
      # local file header signature
      0x04034B50::32-little,
      # version needed to extract
      20::16-little,
      # general purpose bit flag (bit 3: data descriptor, bit 11: utf8 name)
      0x0008 ||| 0x0800::16-little,
      # compression method
      compression::16-little,
      # last mod time
      dos_time(mtime)::16-little,
      # last mod date
      dos_date(mtime)::16-little,
      # crc-32
      0::32,
      # compressed size
      0::32,
      # uncompressed size
      0::32,
      # file name length
      nsize::16-little,
      # extra field length
      0::16,
      # file name
      name::bytes
    >>

    entry = %{
      header: %{
        size: byte_size(local_header),
        name: name,
        nsize: nsize
      },
      entity: %{
        crc: nil,
        size: nil,
        usize: 0,
        csize: 0
      },
      size: nil
    }

    {entry, local_header}
  end

  @spec zip_grow_entry(zip_entry, iodata) :: zip_entry
        when zip_entry: map
  defp zip_grow_entry(entry, data) do
    %{entity: %{crc: crc, usize: usize, csize: csize} = entity} = entry
    size = IO.iodata_length(data)

    crc =
      if crc do
        :erlang.crc32(crc, data)
      else
        :erlang.crc32(data)
      end

    %{entry | entity: %{entity | crc: crc, usize: usize + size, csize: csize + size}}
  end

  @spec zip_end_entry(zip_entry) :: {zip_entry, iodata}
        when zip_entry: map
  defp zip_end_entry(entry) do
    %{
      header: %{size: header_size},
      entity: %{crc: crc, usize: usize, csize: csize} = entity
    } =
      entry

    data_descriptor = <<
      # local file entry signature
      0x08074B50::32-little,
      # crc-32 for the entity
      crc::32-little,
      # compressed size, just the size since we aren't compressing
      csize::32-little,
      # uncompressed size
      usize::32-little
    >>

    entry = %{
      entry
      | entity: %{entity | size: byte_size(data_descriptor) + csize},
        size: byte_size(data_descriptor) + csize + header_size
    }

    {entry, data_descriptor}
  end

  @spec zip_encode_central_directory([zip_entry]) :: iodata
        when zip_entry: map
  def zip_encode_central_directory(entries) do
    context =
      Enum.reduce(entries, %{frames: [], count: 0, offset: 0, size: 0}, fn entry, acc ->
        header = encode_central_file_header(acc, entry)

        acc
        |> Map.update!(:frames, &[header.frame | &1])
        |> Map.update!(:count, &(&1 + 1))
        |> Map.update!(:offset, &(&1 + header.offset))
        |> Map.update!(:size, &(&1 + header.size))
      end)

    frame = <<
      0x06054B50::32-little,
      # number of this disk
      0::16,
      # number of the disk w/ ECD
      0::16,
      # total number of entries in this disk
      context.count::16-little,
      # total number of entries in the ECD
      context.count::16-little,
      # size central directory
      context.size::32-little,
      # offset central directory
      context.offset::32-little,
      # comment length
      0::16
    >>

    [:lists.reverse(context.frames), frame]
  end

  defp encode_central_file_header(context, %{header: header, entity: entity}) do
    mtime = NaiveDateTime.from_erl!(:calendar.local_time())

    frame = <<
      # central file header signature
      0x02014B50::32-little,
      # version made by
      52::16-little,
      # version to extract
      20::16-little,
      # general purpose bit flag (bit 3: data descriptor, bit 11: utf8 name)
      0x0008 ||| 0x0800::16-little,
      # compression method
      0::16-little,
      # last mod file time
      dos_time(mtime)::16-little,
      # last mod date
      dos_date(mtime)::16-little,
      # crc-32
      entity.crc::32-little,
      # compressed size
      entity.csize::32-little,
      # uncompressed size
      entity.usize::32-little,
      # file name length
      header.nsize::16-little,
      # extra field length
      0::16,
      # file comment length
      0::16,
      # disk number start
      0::16,
      # internal file attribute
      0::16,
      # external file attribute (unix permissions, rw-r--r--)
      (0o10 <<< 12 ||| 0o644) <<< 16::32-little,
      # relative offset header
      context.offset::32-little,
      # file name
      header.name::bytes
    >>

    %{frame: frame, size: byte_size(frame), offset: header.size + entity.size}
  end

  defp dos_time(time) do
    round(time.second / 2 + (time.minute <<< 5) + (time.hour <<< 11))
  end

  defp dos_date(time) do
    round(time.day + (time.month <<< 5) + ((time.year - 1980) <<< 9))
  end
end
