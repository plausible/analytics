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

  @callback search(String.t(), pos_integer()) :: list(schema())
  @callback get(pos_integer()) :: schema()
  @callback component() :: module()
  @callback type() :: String.t()
  @callback dump(schema()) :: t()

  defmodule Component do
    @moduledoc false
    @callback render_result(assigns :: Phoenix.LiveView.Socket.assigns()) ::
                Phoenix.LiveView.Rendered.t()
  end

  defmacro __using__(:component) do
    quote do
      use PlausibleWeb, :live_component
      alias Plausible.CustomerSupport.Resource
      import PlausibleWeb.CustomerSupport.Live.Shared

      @behaviour Plausible.CustomerSupport.Resource.Component

      def success(socket, msg) do
        send(socket.root_pid, {:success, msg})
        socket
      end

      def failure(socket, msg) do
        send(socket.root_pid, {:failure, msg})
        socket
      end
    end
  end

  defmacro __using__(component: component) do
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

      @impl true
      def component, do: unquote(component)

      defoverridable component: 0
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
