defmodule Plausible.Export do
  @moduledoc "Exports Plausible data for events and sessions."

  import Ecto.Query
  import Bitwise

  # TODO header
  # TODO sampling
  # TODO checksums (whole archive, each compressed CSV, each decompressed CSV)
  # TODO do in one pass over both tables?
  # TODO scheduling (limit parallel exports)
  def export_queries(site_id) do
    sessions_base_q =
      "sessions_v2"
      |> where(site_id: ^site_id)
      |> group_by([], selected_as(:date))
      |> order_by([s], selected_as(:date))
      |> select([s], %{date: selected_as(fragment("toDate(?)", s.start), :date)})

    exported_visitors_events_q =
      "events_v2"
      |> where(site_id: ^site_id)
      |> group_by([], selected_as(:date))
      |> order_by([e], selected_as(:date))
      |> select([e], %{
        date: selected_as(fragment("toDate(?)", e.timestamp), :date),
        # TODO calc visitors from sessions?
        visitors: fragment("uniq(?)", e.user_id),
        pageviews: fragment("countIf(?='pageview')", e.name)
      })

    exported_visitors_sessions_q =
      select_merge(sessions_base_q, [s], %{
        bounces: sum(s.is_bounce * s.sign),
        visits: sum(s.sign),
        visit_duration: fragment("toUInt32(round(?))", sum(s.duration * s.sign) / sum(s.sign))
      })

    exported_visitors =
      "e"
      |> with_cte("e", as: ^exported_visitors_events_q)
      |> with_cte("s", as: ^exported_visitors_sessions_q)
      # TODO test FULL OUTER JOIN in ch / ecto_ch
      |> join(:full, [e], s in "s", on: e.date == s.date)
      |> select([e, s], [
        selected_as(coalesce(e.date, s.date), :date),
        e.visitors,
        e.pageviews,
        s.bounces,
        s.visits,
        s.visit_duration
      ])
      # TODO need it?
      |> order_by([], selected_as(:date))

    exported_sources =
      sessions_base_q
      |> group_by([s], [
        selected_as(:date),
        s.utm_source,
        s.utm_campaign,
        s.utm_medium,
        s.utm_content,
        s.utm_term
      ])
      |> select_merge([s], %{
        source: selected_as(s.utm_source, :source),
        utm_campaign: s.utm_campaign,
        utm_content: s.utm_content,
        utm_term: s.utm_term,
        visitors: selected_as(fragment("uniq(?)", s.user_id), :visitors),
        visits: selected_as(sum(s.sign), :visits),
        visit_duration:
          selected_as(
            fragment("toUInt32(round(?))", sum(s.duration * s.sign) / sum(s.sign)),
            :visit_duration
          ),
        boucnes: selected_as(sum(s.is_bounce * s.sign), :bounces)
      })

    exported_pages =
      "events_v2"
      # TODO need `where(name: "pageview")`?
      |> where(site_id: ^site_id)
      |> windows([e],
        next: [
          partition_by: e.session_id,
          order_by: e.timestamp,
          frame: fragment("ROWS BETWEEN CURRENT ROW AND 1 FOLLOWING")
        ]
      )
      |> select([e], %{
        session_id: e.session_id,
        timestamp: e.timestamp,
        next_timestamp: over(fragment("leadInFrame(?)", e.timestamp), :next),
        pathname: e.pathname,
        hostname: e.hostname,
        name: e.name,
        user_id: e.user_id
      })
      |> subquery()
      |> select([e], [
        selected_as(fragment("toDate(?)", e.timestamp), :date),
        selected_as(e.pathname, :path),
        selected_as(fragment("any(?)", e.hostname), :hostname),
        selected_as(
          fragment("sum(greatest(?,0))", e.next_timestamp - e.timestamp),
          :time_on_page
        ),
        selected_as(fragment("countIf(?=0)", e.next_timestamp), :exits),
        selected_as(fragment("countIf(?='pageview')", e.name), :pageviews),
        selected_as(fragment("uniq(?)", e.user_id), :visitors)
      ])
      |> group_by([e], [selected_as(:date), e.pathname])
      |> order_by([e], selected_as(:date))

    exported_entry_pages =
      sessions_base_q
      |> group_by([s], [selected_as(:date), s.entry_page])
      |> select_merge([s], %{
        entry_page: s.entry_page,
        visitors: selected_as(fragment("uniq(?)", s.user_id), :visitors),
        entrances: selected_as(sum(s.sign), :entrances),
        visit_duration:
          selected_as(
            fragment("toUInt32(round(?))", sum(s.duration * s.sign) / sum(s.sign)),
            :visit_duration
          ),
        bounces: selected_as(sum(s.is_bounce * s.sign), :bounces)
      })

    exported_exit_pages =
      sessions_base_q
      |> group_by([s], [selected_as(:date), s.exit_page])
      |> select_merge([s], %{
        exit_page: s.exit_page,
        visitors: selected_as(fragment("uniq(?)", s.user_id), :visitors),
        exits: selected_as(sum(s.sign), :exits)
      })

    exported_locations =
      sessions_base_q
      |> group_by([s], [
        selected_as(:date),
        s.country_code,
        selected_as(:region),
        s.city_geoname_id
      ])
      |> select_merge([s], %{
        country: selected_as(s.country_code, :country),
        # TODO
        region:
          selected_as(
            fragment("concatWithSeparator('-',?,?)", s.subdivision1_code, s.subdivision2_code),
            :region
          ),
        city: selected_as(s.city_geoname_id, :city),
        visitors: selected_as(fragment("uniq(?)", s.user_id), :visitors),
        visits: selected_as(sum(s.sign), :visits),
        visit_duration:
          selected_as(
            fragment("toUInt32(round(?))", sum(s.duration * s.sign) / sum(s.sign)),
            :visit_duration
          ),
        bounces: selected_as(sum(s.is_bounce * s.sign), :bounces)
      })

    exported_devices =
      sessions_base_q
      |> group_by([s], [selected_as(:date), s.screen_size])
      |> select_merge([s], %{
        device: selected_as(s.screen_size, :device),
        visitors: selected_as(fragment("uniq(?)", s.user_id), :visitors),
        visits: selected_as(sum(s.sign), :visits),
        visit_duration:
          selected_as(
            fragment("toUInt32(round(?))", sum(s.duration * s.sign) / sum(s.sign)),
            :visit_duration
          ),
        bounces: selected_as(sum(s.is_bounce * s.sign), :bounces)
      })

    exported_browsers =
      sessions_base_q
      |> group_by([s], [selected_as(:date), s.browser])
      |> select_merge([s], %{
        browser: s.browser,
        visitors: selected_as(fragment("uniq(?)", s.user_id), :visitors),
        visits: selected_as(sum(s.sign), :visits),
        visit_duration:
          selected_as(
            fragment("toUInt32(round(?))", sum(s.duration * s.sign) / sum(s.sign)),
            :visit_duration
          ),
        bounces: selected_as(sum(s.is_bounce * s.sign), :bounces)
      })

    exported_operating_systems =
      sessions_base_q
      |> group_by([s], [selected_as(:date), s.operating_system])
      |> select_merge([s], %{
        operating_system: s.operating_system,
        visitors: selected_as(fragment("uniq(?)", s.user_id), :visitors),
        visits: selected_as(sum(s.sign), :visits),
        visit_duration:
          selected_as(
            fragment("toUInt32(round(?))", sum(s.duration * s.sign) / sum(s.sign)),
            :visit_duration
          ),
        bounces: selected_as(sum(s.is_bounce * s.sign), :bounces)
      })

    %{
      visitors: exported_visitors,
      sources: exported_sources,
      pages: exported_pages,
      entry_pages: exported_entry_pages,
      exit_pages: exported_exit_pages,
      locations: exported_locations,
      devices: exported_devices,
      browsers: exported_browsers,
      operating_systems: exported_operating_systems
    }
  end

  @spec export_archive(
          DBConnection.conn(),
          queries :: [{name :: String.t(), sql :: iodata, params :: [term]}],
          on_data :: (iodata -> :ok),
          opts :: Keyword.t()
        ) :: :ok
  def export_archive(conn, queries, on_data, opts \\ []) do
    entries =
      Enum.map(queries, fn {name, sql, params} ->
        Ch.run(conn, fn conn ->
          packets = Ch.stream(conn, sql, params, opts)
          {entry, encoded} = zip_start_entry(name)
          :ok = on_data.(encoded)

          entry =
            Enum.reduce(packets, entry, fn packets, entry ->
              Enum.reduce(packets, entry, fn packet, entry ->
                case packet do
                  {:data, _ref, data} ->
                    :ok = on_data.(data)
                    zip_grow_entry(entry, data)

                  _other ->
                    entry
                end
              end)
            end)

          {entry, encoded} = zip_end_entry(entry)
          :ok = on_data.(encoded)
          entry
        end)
      end)

    :ok = on_data.(zip_encode_central_directory(entries))
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
