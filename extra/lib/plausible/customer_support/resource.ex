defmodule Plausible.CustomerSupport.Resource do
  @moduledoc """
  Generic behaviour for CS resources and their components
  """
  defstruct [:id, :type, :module, :object]

  @type schema() :: map()

  @type t() :: %__MODULE__{
          id: pos_integer(),
          module: atom(),
          object: schema(),
          type: String.t()
        }

  @callback search(String.t(), Keyword.t()) :: list(schema())
  @callback get(pos_integer()) :: schema()
  @callback type() :: String.t()
  @callback dump(schema()) :: t()

  defmacro __using__(_opts) do
    quote do
      @behaviour Plausible.CustomerSupport.Resource
      alias Plausible.CustomerSupport.Resource

      import Ecto.Query
      alias Plausible.Repo

      @impl true
      def dump(schema) do
        Resource.new(__MODULE__, schema)
      end

      defoverridable dump: 1

      @impl true
      def type do
        __MODULE__
        |> Module.split()
        |> Enum.reverse()
        |> hd()
        |> String.downcase()
      end

      defoverridable type: 0
    end
  end

  def new(module, schema) do
    %__MODULE__{
      id: schema.id,
      type: module.type(),
      module: module,
      object: schema
    }
  end
end
