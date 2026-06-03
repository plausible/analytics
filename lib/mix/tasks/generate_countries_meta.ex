defmodule Mix.Tasks.GenerateCountriesMeta do
  @moduledoc """
  Regenerates `countries_meta.json`, an `alpha_2 -> [alpha_3, flag]` dictionary.
  The dashboard uses it for two things.
  First, to render country flags the same way as the BE does.
  Secondly, to map visitors by country to the country shapes in the world map. This is needed
  because country shapes are identified in the geography dataset only with their alpha3 code.

  The source of truth is `Location.Country.all/0` from the `:location`
  dependency. We materialize it to a checked-in JSON file in `assets/` folder.

  The checked-in file is protected from drifting off from the dependency by a CI job.

  Run `mix generate_countries_meta` locally whenever the `:location` dependency is bumped,
  or any time you want to refresh the committed file.
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
        {code, [alpha_3, flag]}
      end)
      |> Jason.encode!(pretty: true)

    File.write!(@output_path, json)
    Mix.shell().info("Wrote #{byte_size(json)} bytes to #{@output_path}")
  end
end
