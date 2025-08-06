defmodule Plausible.CustomerSupport.Resource do
  @moduledoc """
  Generic behaviour for CS resources
  """
  defstruct [:id, :type, :module, :object, :path]

  @type schema() :: map()

  @type t() :: %__MODULE__{
          id: pos_integer(),
          module: atom(),
          object: schema(),
          type: String.t()
        }

  @callback search(String.t(), Keyword.t()) :: list(schema())
  @callback get(pos_integer()) :: schema()
  @callback path(any()) :: String.t()
  @callback dump(schema()) :: t()

  defmacro __using__(type: type) do
    quote do
      @behaviour Plausible.CustomerSupport.Resource
      alias Plausible.CustomerSupport.Resource
      alias PlausibleWeb.Router.Helpers, as: Routes

      import Ecto.Query
      alias Plausible.Repo

      @impl true
      def dump(schema) do
        new(__MODULE__, schema)
      end

      defoverridable dump: 1

      def new(module, schema) do
        %Resource{
          id: schema.id,
          type: unquote(type),
          path: module.path(schema.id),
          module: module,
          object: schema
        }
      end
    end
  end
end
