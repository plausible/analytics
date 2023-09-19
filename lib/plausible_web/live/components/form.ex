defmodule PlausibleWeb.Live.Components.Form do
  @moduledoc """
  Generic components stolen from mix phx.new templates
  """

  use Phoenix.Component

  @doc """
  Renders an input with label and error messages.

  A `Phoenix.HTML.FormField` may be passed as argument,
  which is used to retrieve the input name, id, and values.
  Otherwise all attributes may be passed explicitly.

  ## Examples

  <.input field={@form[:email]} type="email" />
  <.input name="my-input" errors={["oh no!"]} />
  """
  attr(:id, :any, default: nil)
  attr(:name, :any)
  attr(:label, :string, default: nil)
  attr(:value, :any)

  attr(:type, :string,
    default: "text",
    values: ~w(checkbox color date datetime-local email file hidden month number password
         range radio search select tel text textarea time url week)
  )

  attr(:field, Phoenix.HTML.FormField,
    doc: "a form field struct retrieved from the form, for example: @form[:email]"
  )

  attr(:errors, :list, default: [])
  attr(:checked, :boolean, doc: "the checked flag for checkbox inputs")
  attr(:prompt, :string, default: nil, doc: "the prompt for select inputs")
  attr(:options, :list, doc: "the options to pass to Phoenix.HTML.Form.options_for_select/2")
  attr(:multiple, :boolean, default: false, doc: "the multiple flag for select inputs")

  attr(:rest, :global,
    include: ~w(accept autocomplete capture cols disabled form list max maxlength min minlength
         multiple pattern placeholder readonly required rows size step)
  )

  slot(:inner_block)

  def input(%{field: %Phoenix.HTML.FormField{} = field} = assigns) do
    assigns
    |> assign(field: nil, id: assigns.id || field.id)
    |> assign(:errors, Enum.map(field.errors, &translate_error(&1)))
    |> assign_new(:name, fn -> if assigns.multiple, do: field.name <> "[]", else: field.name end)
    |> assign_new(:value, fn -> field.value end)
    |> input()
  end

  # All other inputs text, datetime-local, url, password, etc. are handled here...
  def input(assigns) do
    ~H"""
    <div phx-feedback-for={@name}>
      <.label :if={@label != nil and @label != ""} for={@id}>
        <%= @label %>
      </.label>
      <input
        type={@type}
        name={@name}
        id={@id}
        value={Phoenix.HTML.Form.normalize_value(@type, @value)}
        {@rest}
      />
      <%= render_slot(@inner_block) %>
      <.error :for={msg <- @errors}>
        <%= msg %>
      </.error>
    </div>
    """
  end

  attr(:id, :any, default: nil)
  attr(:label, :string, default: nil)

  attr(:field, Phoenix.HTML.FormField,
    doc: "a form field struct retrieved from the form, for example: @form[:password]",
    required: true
  )

  attr(:strength, :any)

  attr(:rest, :global,
    include: ~w(autocomplete disabled form maxlength minlength readonly required size)
  )

  def password_input_with_strength(%{field: field} = assigns) do
    {too_weak?, errors} =
      case pop_strength_errors(field.errors) do
        {strength_errors, other_errors} when strength_errors != [] ->
          {true, other_errors}

        {[], other_errors} ->
          {false, other_errors}
      end

    strength =
      if too_weak? and assigns.strength.score >= 3 do
        %{assigns.strength | score: 2}
      else
        assigns.strength
      end

    assigns =
      assigns
      |> assign(:non_empty?, String.length(field.value || "") > 0)
      |> assign(:field, %{field | errors: errors})
      |> assign(:strength, strength)

    ~H"""
    <.input field={@field} type="password" label={@label} id={@id} {@rest}>
      <.strength_meter :if={@non_empty?} {@strength} />
    </.input>
    """
  end

  attr(:minimum, :integer, required: true)

  attr(:field, Phoenix.HTML.FormField,
    doc: "a form field struct retrieved from the form, for example: @form[:password]",
    required: true
  )

  def password_length_hint(%{field: field} = assigns) do
    {strength_errors, _} = pop_strength_errors(field.errors)

    color =
      if :length in strength_errors do
        "text-red-500"
      else
        "text-gray-500"
      end

    assigns = assign(assigns, :color, color)

    ~H"""
    <p class={["text-xs", @color, "mt-1"]}>Min <%= @minimum %> characters</p>
    """
  end

  defp pop_strength_errors(errors) do
    {strength_errors, other_errors} =
      Enum.split_with(errors, &(elem(&1, 1)[:validation] == :strength))

    {length_errors, other_errors} =
      Enum.split_with(other_errors, &(elem(&1, 1)[:validation] == :length))

    detected =
      if strength_errors != [] do
        [:strength]
      else
        []
      end

    if length_errors != [] do
      [{_, meta}] = length_errors

      if meta[:kind] == :min do
        {[:length | detected], other_errors}
      else
        {detected, length_errors ++ other_errors}
      end
    else
      {detected, other_errors}
    end
  end

  attr(:score, :integer, default: 0)
  attr(:warning, :string, default: "")
  attr(:suggestions, :list, default: [])

  def strength_meter(assigns) do
    color =
      cond do
        assigns.score <= 1 -> ["bg-red-500", "dark:bg-red-500"]
        assigns.score == 2 -> ["bg-red-300", "dark:bg-red-300"]
        assigns.score == 3 -> ["bg-blue-300", "dark:bg-blue-300"]
        assigns.score >= 4 -> ["bg-blue-600", "dark:bg-blue-500"]
      end

    assigns = assign(assigns, :color, color)

    ~H"""
    <div class="w-full bg-gray-200 rounded-full h-1.5 mb-2 mt-2 dark:bg-gray-700 mt-1">
      <div
        class={["h-1.5", "rounded-full"] ++ @color}
        style={["width: " <> to_string(@score * 25) <> "%"]}
      >
      </div>
    </div>
    <p :if={@score <= 2} class="text-sm text-red-500 phx-no-feedback:hidden">
      Password is too weak
    </p>
    <p :if={@warning != "" or @suggestions != []} class="text-xs text-gray-500">
      <span :if={@warning != ""}>
        <%= @warning %>.
      </span>
      <span :for={suggestion <- @suggestions}>
        <%= suggestion %>
      </span>
    </p>
    """
  end

  @doc """
  Renders a label.
  """
  attr(:for, :string, default: nil)
  slot(:inner_block, required: true)

  def label(assigns) do
    ~H"""
    <label for={@for} class="block font-medium dark:text-gray-100">
      <%= render_slot(@inner_block) %>
    </label>
    """
  end

  @doc """
  Generates a generic error message.
  """
  slot(:inner_block, required: true)

  def error(assigns) do
    ~H"""
    <p class="flex gap-3 text-sm leading-6 text-red-500 phx-no-feedback:hidden">
      <%= render_slot(@inner_block) %>
    </p>
    """
  end

  def translate_error({msg, opts}) do
    Enum.reduce(opts, msg, fn {key, value}, acc ->
      String.replace(acc, "%{#{key}}", fn _ -> to_string(value) end)
    end)
  end
end
