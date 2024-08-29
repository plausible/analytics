defmodule PlausibleWeb.Flows do
  @moduledoc """
  Static compile-time definitions for user progress flows.
  See `PlausibleWeb.Components.FlowProgress` for rendering capabilities.
  """

  @flows %{
    review: [
      "Install Plausible",
      "Verify installation"
    ],
    domain_change: [
      "Set up new domain",
      "Install Plausible",
      "Verify installation"
    ],
    register: [
      "Register",
      "Activate account",
      "Add site info",
      "Install Plausible",
      "Verify installation"
    ],
    invitation: [
      "Register",
      "Activate account"
    ],
    provisioning: [
      "Add site info",
      "Install Plausible",
      "Verify installation"
    ]
  }

  @valid_values @flows
                |> Enum.flat_map(fn {_, steps} -> steps end)
                |> Enum.uniq()

  @valid_keys @flows
              |> Map.keys()
              |> Enum.map(&to_string/1)

  @spec steps(binary() | atom()) :: list(binary())
  def steps(flow) when flow in @valid_keys do
    steps(String.to_existing_atom(flow))
  end

  def steps(flow) when is_atom(flow) do
    Map.get(@flows, flow, [])
  end

  def steps(_), do: []

  @spec valid_values() :: list(binary())
  def valid_values(), do: @valid_values

  @spec valid_values() :: list(binary())
  def valid_keys(), do: @valid_keys

  for {flow, _} <- @flows do
    @spec unquote(flow)() :: binary()
    def unquote(flow)(), do: unquote(to_string(flow))
  end
end
