defmodule Mix.Tasks.GenerateCountriesMeta do
  @moduledoc """
  Regenerates `countries_meta.json` — the compact
  `alpha_2 -> %{alpha_3, flag}` lookup the dashboard frontend uses to
  render country flags and to do the world map's alpha-2 -> alpha-3 join.

  The source of truth is `Location.Country.all/0` from the `:location` Hex
  dependency. We materialize it to a checked-in JSON file in `assets/` folder.

  The checked-in file is protected from drifting off from the Hex dependency by a CI job.

  Run `mix generate_countries_meta` locally whenever the `:location` dependency is bumped, or any time you want to
  refresh the committed file.
  """

  use Mix.Task

  @output_path "assets/data/countries_meta.json"

  @impl Mix.Task
  def run(_args) do
    Application.ensure_all_started(:jason)
    Location.Country.load()

    json =
      Location.Country.all()
      |> Map.new(fn %Location.Country{
                      alpha_2: code,
                      alpha_3: alpha_3,
                      flag: flag
                    } ->
        {code, %{alpha_3: alpha_3, flag: flag}}
      end)
      |> Jason.encode!()

    File.write!(@output_path, json)
    Mix.shell().info("Wrote #{byte_size(json)} bytes to #{@output_path}")
  end
end
