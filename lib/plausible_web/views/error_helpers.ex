defmodule PlausibleWeb.ErrorHelpers do
  use Phoenix.HTML

  def error_tag(form, field) do
    Enum.map(Keyword.get_values(form.errors, field), fn error ->
      content_tag(:div, elem(error, 0), class: "text-red-500 text-xs italic mt-3")
    end)
  end
end
