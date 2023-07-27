defmodule PlausibleWeb.ErrorHelpers do
  use Phoenix.HTML

  def error_tag(%Phoenix.HTML.Form{} = form, field) do
    Enum.map(Keyword.get_values(form.errors, field), fn error ->
      content_tag(:div, translate_error(error), class: "mt-2 text-sm text-red-600")
    end)
  end

  def error_tag(assigns, field) when is_map(assigns) do
    error = assigns[field]

    if error do
      content_tag(:div, error, class: "mt-2 text-sm text-red-600")
    end
  end

  def translate_error({msg, opts}) do
    Enum.reduce(opts, msg, fn {key, value}, acc ->
      String.replace(acc, "%{#{key}}", fn _ -> to_string(value) end)
    end)
  end
end
