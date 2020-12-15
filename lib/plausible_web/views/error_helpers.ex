defmodule PlausibleWeb.ErrorHelpers do
  use Phoenix.HTML

  def error_tag(%Phoenix.HTML.Form{} = form, field) do
    Enum.map(Keyword.get_values(form.errors, field), fn error ->
      content_tag(:div, elem(error, 0), class: "mt-2 text-sm text-red-600")
    end)
  end

  def error_tag(assigns, field) when is_map(assigns) do
    error = assigns[field]

    if error do
      content_tag(:div, error, class: "mt-2 text-sm text-red-600")
    end
  end
end
