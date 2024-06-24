defmodule Plausible.LiveViewTest do
  @moduledoc """
  Temporary fix for `Phoenix.LiveViewTest.render_component/2` failing CI with warnings.

  This module can be removed once Plausible switches to `phoenix_live_view ~> 1.0.0`
  """

  @doc """
  Same as `Phoenix.LiveViewTest.render_component/2` but with backported fixes from
  https://github.com/phoenixframework/phoenix_live_view/commit/489e8de024e03976e9ae38138eec517fbd456d27
  """
  defmacro render_component(component, assigns \\ Macro.escape(%{}), opts \\ []) do
    endpoint = Module.get_attribute(__CALLER__.module, :endpoint)

    component =
      if is_atom(component) do
        quote do
          unquote(component).__live__()
          unquote(component)
        end
      else
        component
      end

    quote do
      Plausible.LiveViewTest.__render_component__(
        unquote(endpoint),
        unquote(component),
        unquote(assigns),
        unquote(opts)
      )
    end
  end

  def __render_component__(endpoint, component, assigns, opts) when is_atom(component) do
    Phoenix.LiveViewTest.__render_component__(endpoint, %{module: component}, assigns, opts)
  end

  def __render_component__(endpoint, component, assigns, opts) do
    Phoenix.LiveViewTest.__render_component__(endpoint, component, assigns, opts)
  end
end
