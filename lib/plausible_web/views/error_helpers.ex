defmodule PlausibleWeb.ErrorHelpers do
  @moduledoc false
  use Phoenix.HTML

  def error_tag(map_or_form, field, opts \\ [])

  def error_tag(%{errors: errors}, field, opts) do
    error_messages = Keyword.get_values(errors, field)

    error_messages =
      if Keyword.get(opts, :only_first?) do
        Enum.take(error_messages, 1)
      else
        error_messages
      end

    Enum.map(error_messages, fn error ->
      content_tag(:div, translate_error(error), class: "mt-2 text-sm text-red-500")
    end)
  end

  def error_tag(assigns, field, _opts) when is_map(assigns) do
    error = assigns[field]

    if error do
      content_tag(:div, error, class: "mt-2 text-sm text-red-500")
    end
  end

  def translate_error({msg, opts}) do
    Enum.reduce(opts, msg, fn {key, value}, acc ->
      String.replace(acc, "%{#{key}}", fn _ -> to_string(value) end)
    end)
  end
end
