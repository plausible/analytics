# Builds a capability map from `# capability:begin` ... `# capability:end`
# comment blocks in lib/ and extra/lib/.
#
#     elixir scripts/capability_map.exs [--format md|json|csv] [--out PATH]
#
# Standard library only, no app compile. Exits non-zero on validation errors.

defmodule CapabilityMap do
  # Editable lists. Refine together with the auth design.

  @scope_vocabulary ~w(stats:read sites:read sites:write sites:provision access:write teams:create)

  # Proposed scopes for a separate /cs/mcp protected resource, so CS grants
  # never mix with customer grants. Super admin only.
  @cs_scope_vocabulary ~w(cs:read cs:write cs:billing cs:delete)

  # Proposed scope for actions that stay session-only and are never
  # grantable to tokens (billing, account security, credential management).
  @session_only_scope "none"

  # Entry points deliberately left without a capability block, with the reason.
  @not_mapped [
    {"Registration, login, activation, password reset, 2FA setup and verification, SSO login and SAML, logout",
     "Authentication flows: they establish a session, they are not actions on a resource"},
    {"OAuth authorize, token and /.well-known metadata",
     "They issue credentials; the capabilities are on the resources the credentials reach"},
    {"POST /api/event, GET /api/error", "Tracker ingestion, public by design"},
    {"/api/paddle/webhook, /api/postmark/webhook, /api/paddle/currency",
     "Third-party webhooks and billing helpers"},
    {"/api/health, /api/system/*", "Health checks"},
    {"/flags/*, /debug/clickhouse",
     "Super admin tooling outside customer support (feature flags UI, ClickHouse debug)"},
    {"/helpscout/*", "Support integration authenticated by HelpScout"},
    {"/dev/*, /plug-tests/*, /e2e-tests/*, /sent-emails*", "Dev, test and e2e only"},
    {"Pages that load no data beyond a mapped read: new site, new API key, *_form, danger zones, settings_visibility, settings_shields, preferences, the settings index redirects",
     "Reads are mapped on the handler that loads the data (controller action or LiveView mount/update), not per page"},
    {"Billing pages (choose plan, upgrade, previews, ping) and the ChoosePlan LiveView",
     "Billing is never grantable to tokens; get_subscription and change_plan are mapped"},
    {"Avatar, error report, GET /", "Not actions on a resource"},
    {"Plugins API /spec/* and /v1/capabilities, GET /api/docs/query/schema.json",
     "Public metadata"},
    {"MCP server/discover and tools/list", "Protocol methods, not capabilities"},
    {"UI-only LiveView events (filter, sort, modals, CTA dismissals, form validation)",
     "Change only the LiveView's own state"}
  ]

  # Current scope strings and the vocabulary scope they map to. Used only to
  # decide whether a row's scope drifts.
  @legacy_scope_aliases %{
    "stats:read:*" => "stats:read",
    "sites:read:*" => "sites:read",
    "sites:provision:*" => "sites:provision"
  }

  @transports ~w(ui_session internal_api public_api_v1 public_api_v2 sites_api mcp shared_link plugins_api other)

  # plugins_token: Plugins API token, bound to one site, no user.
  @credentials ~w(session api_key_legacy api_key_team oauth shared_link plugins_token none)

  # Credentials that carry scopes (or should). Rows accepting only other
  # credentials are not flagged for missing scope enforcement, because UI
  # sessions are treated as having every scope.
  @token_credentials ~w(api_key_legacy api_key_team oauth plugins_token)

  # An empty role list means no team role applies (account-level actions,
  # credentials without a user).
  @roles ~w(owner admin editor viewer billing guest_viewer guest_editor public super_admin)

  # Super admin is a single bypass in the policy, not a role to compare.
  @drift_ignored_roles ~w(super_admin)

  @resources ~w(site team account none)
  @confidence ~w(verified inferred)

  @required_keys ~w(id action transport entry handler credential resource current_scope
                    current_scope_enforced_by current_roles current_role_enforced_by
                    proposed_scope proposed_roles confidence)
  @optional_keys ~w(current_feature_gate notes)
  @list_keys ~w(credential current_roles proposed_roles current_feature_gate)

  @scan_dirs ["lib", "extra/lib"]
  @default_out "docs/capability_map.md"

  @begin_marker "# capability:begin"
  @end_marker "# capability:end"

  def main(argv) do
    {opts, _, invalid} = OptionParser.parse(argv, strict: [format: :string, out: :string])

    if invalid != [] do
      fail(["unknown options: #{inspect(invalid)}"])
    end

    format = Keyword.get(opts, :format, "md")

    unless format in ~w(md json csv) do
      fail(["--format must be md, json or csv"])
    end

    out = Keyword.get(opts, :out, default_out(format))

    {blocks, errors, warnings} = collect()
    errors = errors ++ validate_unique_ids(blocks)

    Enum.each(warnings, &IO.puts(:stderr, "warning: " <> &1))

    if errors != [] do
      fail(errors)
    end

    blocks = Enum.sort_by(blocks, &{&1["action"], transport_index(&1["transport"])})

    content =
      case format do
        "md" -> render_md(blocks)
        "json" -> IO.iodata_to_binary([to_json(blocks), "\n"])
        "csv" -> render_csv(blocks)
      end

    File.mkdir_p!(Path.dirname(out))
    File.write!(out, content)
    IO.puts("#{length(blocks)} capability blocks -> #{out}")
  end

  defp default_out("md"), do: @default_out
  defp default_out(format), do: Path.rootname(@default_out) <> "." <> format

  defp fail(errors) do
    Enum.each(errors, &IO.puts(:stderr, "error: " <> &1))
    System.halt(1)
  end

  ## Scanning

  defp collect do
    @scan_dirs
    |> Enum.flat_map(&Path.wildcard(Path.join(&1, "**/*.{ex,exs}")))
    |> Enum.sort()
    |> Enum.reduce({[], [], []}, fn path, {blocks, errors, warnings} ->
      {b, e, w} = scan_file(path)
      {blocks ++ b, errors ++ e, warnings ++ w}
    end)
  end

  defp scan_file(path) do
    lines = path |> File.read!() |> String.split("\n")
    indexed = Enum.with_index(lines, 1)

    {blocks, errors, current} =
      Enum.reduce(indexed, {[], [], nil}, fn {line, n}, {blocks, errors, current} ->
        trimmed = String.trim(line)

        cond do
          trimmed == @begin_marker and current != nil ->
            {blocks, errors ++ ["#{path}:#{n}: nested #{@begin_marker}"], {n, []}}

          trimmed == @begin_marker ->
            {blocks, errors, {n, []}}

          trimmed == @end_marker and current == nil ->
            {blocks, errors ++ ["#{path}:#{n}: #{@end_marker} without begin"], nil}

          trimmed == @end_marker ->
            {start, body} = current
            {blocks ++ [{start, n, Enum.reverse(body)}], errors, nil}

          current != nil and String.starts_with?(trimmed, "#") ->
            {start, body} = current
            {blocks, errors, {start, [{n, trimmed} | body]}}

          current != nil ->
            {start, _} = current
            {blocks, errors ++ ["#{path}:#{start}: block not closed before code"], nil}

          true ->
            {blocks, errors, current}
        end
      end)

    errors =
      case current do
        {start, _} -> errors ++ ["#{path}:#{start}: block not closed at end of file"]
        nil -> errors
      end

    Enum.reduce(blocks, {[], errors, []}, fn {start, stop, body}, {acc, errs, warns} ->
      case parse_block(path, start, body) do
        {:ok, block} ->
          {block_errors, block_warnings} = validate(block)
          handler_warnings = check_handler(block, lines, stop)
          {acc ++ [block], errs ++ block_errors, warns ++ block_warnings ++ handler_warnings}

        {:error, parse_errors} ->
          {acc, errs ++ parse_errors, warns}
      end
    end)
  end

  defp parse_block(path, start, body) do
    {map, errors} =
      Enum.reduce(body, {%{}, []}, fn {n, line}, {map, errors} ->
        content = line |> String.trim_leading("#") |> String.trim()

        case String.split(content, ":", parts: 2) do
          [""] ->
            {map, errors}

          [key, value] ->
            key = String.trim(key)

            cond do
              key not in @required_keys and key not in @optional_keys ->
                {map, errors ++ ["#{path}:#{n}: unknown key #{inspect(key)}"]}

              Map.has_key?(map, key) ->
                {map, errors ++ ["#{path}:#{n}: duplicate key #{inspect(key)}"]}

              true ->
                {Map.put(map, key, parse_value(key, String.trim(value))), errors}
            end

          _ ->
            {map, errors ++ ["#{path}:#{n}: expected `key: value`, got #{inspect(content)}"]}
        end
      end)

    if errors == [] do
      {:ok, Map.merge(map, %{"source_file" => path, "source_line" => start})}
    else
      {:error, errors}
    end
  end

  defp parse_value(key, value) when key in @list_keys do
    case Regex.run(~r/^\[(.*)\]$/, value) do
      [_, inner] -> inner |> String.split(",", trim: true) |> Enum.map(&String.trim/1)
      nil -> value
    end
  end

  defp parse_value(_key, value), do: value

  ## Validation

  defp validate(block) do
    loc = "#{block["source_file"]}:#{block["source_line"]}"
    missing = Enum.reject(@required_keys, &Map.has_key?(block, &1))

    errors =
      Enum.map(missing, &"#{loc}: missing required key #{inspect(&1)}") ++
        if missing == [] do
          validate_values(block, loc)
        else
          []
        end

    {errors, []}
  end

  defp validate_values(block, loc) do
    checks = [
      {block["transport"] in @transports, "transport #{inspect(block["transport"])} not in enum"},
      {block["resource"] in @resources, "resource #{inspect(block["resource"])} not in enum"},
      {block["confidence"] in @confidence,
       "confidence #{inspect(block["confidence"])} not in enum"},
      {list_in?(block["credential"], @credentials),
       "credential must be a list from #{inspect(@credentials)}"},
      {block["current_roles"] == "unknown" or list_in?(block["current_roles"], @roles),
       "current_roles must be `unknown` or a list from #{inspect(@roles)}"},
      {list_in?(block["proposed_roles"], @roles),
       "proposed_roles must be a list from #{inspect(@roles)}"},
      {block["id"] == "#{block["action"]}@#{block["transport"]}",
       "id #{inspect(block["id"])} must equal action@transport"},
      {Regex.match?(~r/^[a-z][a-z0-9_]*$/, block["action"] || ""),
       "action #{inspect(block["action"])} must be snake_case"},
      {Regex.match?(~r/^[A-Z][\w.]*\.[a-z_][a-z0-9_?!]*\/\d+$/, block["handler"] || ""),
       "handler #{inspect(block["handler"])} must be Module.function/arity"},
      {block["proposed_scope"] in @scope_vocabulary or
         block["proposed_scope"] in @cs_scope_vocabulary or
         block["proposed_scope"] == @session_only_scope or
         String.starts_with?(block["notes"] || "", "NEW SCOPE:"),
       "proposed_scope #{inspect(block["proposed_scope"])} not in vocabulary " <>
         "(start notes with `NEW SCOPE:` to propose one)"}
    ]

    for {false, message} <- checks, do: "#{loc}: #{message}"
  end

  defp list_in?(list, allowed) when is_list(list), do: Enum.all?(list, &(&1 in allowed))
  defp list_in?(_, _), do: false

  defp validate_unique_ids(blocks) do
    blocks
    |> Enum.group_by(& &1["id"])
    |> Enum.filter(fn {_id, group} -> length(group) > 1 end)
    |> Enum.map(fn {id, group} ->
      locs = Enum.map_join(group, ", ", &"#{&1["source_file"]}:#{&1["source_line"]}")
      "duplicate id #{inspect(id)} at #{locs}"
    end)
  end

  # Warns when the code right after the block isn't a `def` matching `handler`.
  # Blocks in the router sit above routes and MCP blocks sit above tool specs,
  # so both are skipped.
  defp check_handler(block, lines, stop_line) do
    loc = "#{block["source_file"]}:#{block["source_line"]}"

    with false <- String.ends_with?(block["source_file"], "router.ex"),
         false <- block["transport"] == "mcp",
         [_, module, fun] <-
           Regex.run(~r/^([A-Z][\w.]*)\.([a-z_][a-z0-9_?!]*)\/\d+$/, block["handler"] || "") do
      rest = Enum.drop(lines, stop_line)

      code_index =
        Enum.find_index(rest, fn line ->
          trimmed = String.trim(line)
          trimmed != "" and not String.starts_with?(trimmed, "#")
        end)

      def_index =
        if code_index &&
             Regex.match?(~r/^\s*defp?\s+[a-z_][a-z0-9_?!]*[\s(]/, Enum.at(rest, code_index)),
           do: code_index

      module_warnings =
        case enclosing_module(lines, stop_line) do
          nil -> []
          ^module -> []
          other -> ["#{loc}: handler module #{module} but block is inside #{other}"]
        end

      def_warnings =
        case def_index do
          nil ->
            ["#{loc}: block is not directly above a def (handler #{block["handler"]})"]

          index ->
            [_, name] = Regex.run(~r/^\s*defp?\s+([a-z_][a-z0-9_?!]*)/, Enum.at(rest, index))

            cond do
              name != fun ->
                ["#{loc}: next def is #{name}, handler says #{fun}"]

              fun == "handle_event" ->
                check_event(loc, block["entry"], Enum.slice(rest, index, 4))

              true ->
                []
            end
        end

      module_warnings ++ def_warnings
    else
      _ -> []
    end
  end

  defp check_event(loc, entry, def_lines) do
    expected = Regex.run(~r/handle_event "([^"]+)"/, entry || "")
    actual = Regex.run(~r/"([^"]+)"/, Enum.join(def_lines, " "))

    case {expected, actual} do
      {[_, same], [_, same]} -> []
      {nil, _} -> ["#{loc}: handle_event handler but entry has no `handle_event \"<event>\"`"]
      {[_, e], [_, a]} -> ["#{loc}: entry event #{inspect(e)} but next def handles #{inspect(a)}"]
      {_, nil} -> ["#{loc}: could not read event name of next handle_event"]
    end
  end

  defp enclosing_module(lines, line) do
    lines
    |> Enum.take(line)
    |> Enum.reverse()
    |> Enum.find_value(fn l ->
      case Regex.run(~r/^\s*defmodule\s+([A-Z][\w.]*)\s+do/, l) do
        [_, module] -> module
        nil -> nil
      end
    end)
  end

  ## Rendering

  @current_columns [
    {"Action", "action"},
    {"Transport", "transport"},
    {"Entry", "entry"},
    {"Credential", "credential"},
    {"Resource", "resource"},
    {"Current scope", "current_scope"},
    {"Scope enforced by", "current_scope_enforced_by"},
    {"Current roles", "current_roles"},
    {"Role enforced by", "current_role_enforced_by"},
    {"Feature gate", "current_feature_gate"},
    {"Confidence", "confidence"},
    {"Source", :source}
  ]

  @ideal_columns [
    {"Action", "action"},
    {"Transport", "transport"},
    {"Proposed scope", "proposed_scope"},
    {"Proposed roles", "proposed_roles"},
    {"Resource", "resource"}
  ]

  defp render_md(blocks) do
    [
      "# Capability map\n\n",
      "Generated by `elixir scripts/capability_map.exs` from `# capability:begin` blocks. ",
      "Do not edit by hand.\n\n",
      "#{length(blocks)} blocks, ",
      "#{blocks |> Enum.map(& &1["action"]) |> Enum.uniq() |> length()} actions.\n\n",
      "## 1. Current state\n\n",
      md_table(@current_columns, blocks),
      "\n## 2. Ideal state\n\n",
      md_table(@ideal_columns, blocks),
      "\n## 3. Drift\n\n",
      "Scope drift compares the current scope (legacy strings mapped to the vocabulary) ",
      "with the proposed one. Role drift ignores #{Enum.join(@drift_ignored_roles, ", ")}, ",
      "the policy bypass. Missing scope enforcement is only flagged for rows that accept ",
      "a token credential (#{Enum.join(@token_credentials, ", ")}).\n\n",
      render_drift(blocks),
      "\n## 4. Coverage matrix\n\n",
      render_coverage(blocks),
      "\n## 5. Notes and open questions\n\n",
      render_notes(blocks),
      "## 6. Not mapped\n\n",
      "Proposed scope `#{@session_only_scope}` in the tables above means session only, ",
      "never grantable to tokens. These entry points have no block at all:\n\n",
      md_table([{"Entry points", 0}, {"Why", 1}], @not_mapped)
    ]
    |> IO.iodata_to_binary()
  end

  defp md_table(columns, rows) do
    header = "| " <> Enum.map_join(columns, " | ", &elem(&1, 0)) <> " |\n"
    sep = "|" <> String.duplicate("---|", length(columns)) <> "\n"

    body =
      Enum.map(rows, fn row ->
        "| " <>
          Enum.map_join(columns, " | ", fn {_, key} -> md_cell(cell(row, key)) end) <> " |\n"
      end)

    [header, sep, body]
  end

  defp cell(row, :source), do: "#{row["source_file"]}:#{row["source_line"]}"
  defp cell(row, index) when is_tuple(row), do: elem(row, index)
  defp cell(row, key), do: format_value(row[key])

  defp format_value(nil), do: ""
  defp format_value(list) when is_list(list), do: Enum.join(list, ", ")
  defp format_value(value), do: to_string(value)

  defp md_cell(value), do: value |> String.replace("|", "\\|") |> String.replace("\n", " ")

  defp render_drift(blocks) do
    rows =
      for block <- blocks, reasons = drift_reasons(block), reasons != [] do
        Map.put(block, "drift", Enum.join(reasons, "; "))
      end

    if rows == [] do
      "No drift.\n"
    else
      md_table(
        [
          {"Action", "action"},
          {"Transport", "transport"},
          {"Drift", "drift"},
          {"Source", :source}
        ],
        rows
      )
    end
  end

  defp drift_reasons(block) do
    current_scope = Map.get(@legacy_scope_aliases, block["current_scope"], block["current_scope"])
    token? = Enum.any?(List.wrap(block["credential"]), &(&1 in @token_credentials))

    scope =
      cond do
        block["current_scope"] == "none" and token? ->
          ["scope: none -> #{block["proposed_scope"]}"]

        block["current_scope"] != "none" and current_scope != block["proposed_scope"] ->
          ["scope: #{block["current_scope"]} -> #{block["proposed_scope"]}"]

        true ->
          []
      end

    roles =
      case block["current_roles"] do
        "unknown" ->
          ["current roles unknown"]

        current ->
          current = current -- @drift_ignored_roles
          proposed = block["proposed_roles"] -- @drift_ignored_roles
          added = proposed -- current
          removed = current -- proposed

          if added == [] and removed == [] do
            []
          else
            [
              "roles: " <>
                Enum.join(
                  Enum.map(added, &"+#{&1}") ++ Enum.map(removed, &"-#{&1}"),
                  " "
                )
            ]
          end
      end

    enforcement =
      if(token? and unenforced?(block["current_scope_enforced_by"]),
        do: ["scope enforced by: #{block["current_scope_enforced_by"]}"],
        else: []
      ) ++
        if unenforced?(block["current_role_enforced_by"]),
          do: ["role enforced by: #{block["current_role_enforced_by"]}"],
          else: []

    scope ++ roles ++ enforcement
  end

  # `none (membership only; ...)` still means no role check.
  defp unenforced?(value), do: String.starts_with?(value || "", ["none", "unknown"])

  defp render_coverage(blocks) do
    by_action = Enum.group_by(blocks, & &1["action"])
    actions = by_action |> Map.keys() |> Enum.sort()

    header = "| Action | " <> Enum.join(@transports, " | ") <> " |\n"
    sep = "|---|" <> String.duplicate(":---:|", length(@transports)) <> "\n"

    body =
      Enum.map(actions, fn action ->
        transports = Enum.map(by_action[action], & &1["transport"])
        marks = Enum.map_join(@transports, " | ", &if(&1 in transports, do: "✓", else: ""))
        "| #{action} | #{marks} |\n"
      end)

    [header, sep, body]
  end

  defp render_notes(blocks) do
    blocks
    |> Enum.filter(&(&1["notes"] not in [nil, ""]))
    |> Enum.group_by(& &1["action"])
    |> Enum.sort_by(&elem(&1, 0))
    |> Enum.map(fn {action, rows} ->
      items =
        Enum.map(rows, fn row ->
          notes =
            row["notes"]
            |> String.split(";")
            |> Enum.map(&String.trim/1)
            |> Enum.reject(&(&1 == ""))

          case notes do
            [single] ->
              "- **#{row["transport"]}**: #{single}\n"

            many ->
              ["- **#{row["transport"]}**:\n", Enum.map(many, &"  - #{&1}\n")]
          end
        end)

      ["### #{action}\n\n", items, "\n"]
    end)
  end

  defp render_csv(blocks) do
    keys =
      @required_keys ++ @optional_keys ++ ["source_file", "source_line"]

    header = Enum.join(keys, ",") <> "\n"

    rows =
      Enum.map(blocks, fn block ->
        Enum.map_join(keys, ",", &csv_escape(format_value(block[&1]))) <> "\n"
      end)

    IO.iodata_to_binary([header, rows])
  end

  # Minimal encoder, so the script doesn't depend on Elixir 1.18's JSON module.
  defp to_json(list) when is_list(list),
    do: ["[", Enum.intersperse(Enum.map(list, &to_json/1), ","), "]"]

  defp to_json(map) when is_map(map) do
    pairs =
      map
      |> Enum.sort()
      |> Enum.map(fn {k, v} -> [to_json(to_string(k)), ":", to_json(v)] end)

    ["{", Enum.intersperse(pairs, ","), "}"]
  end

  defp to_json(int) when is_integer(int), do: Integer.to_string(int)

  defp to_json(string) when is_binary(string) do
    escaped =
      for <<c::utf8 <- string>>, into: "" do
        case c do
          ?" -> "\\\""
          ?\\ -> "\\\\"
          ?\n -> "\\n"
          c when c < 0x20 -> "\\u" <> String.pad_leading(Integer.to_string(c, 16), 4, "0")
          c -> <<c::utf8>>
        end
      end

    [?", escaped, ?"]
  end

  defp csv_escape(value) do
    if String.contains?(value, [",", "\"", "\n"]) do
      "\"" <> String.replace(value, "\"", "\"\"") <> "\""
    else
      value
    end
  end

  defp transport_index(transport), do: Enum.find_index(@transports, &(&1 == transport)) || 99
end

CapabilityMap.main(System.argv())
