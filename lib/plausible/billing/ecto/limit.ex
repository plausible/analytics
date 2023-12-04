defmodule Plausible.Billing.Ecto.Limit do
  @moduledoc """
  Ecto type representing a limit, that can be either a number or unlimited.
  Unlimited is dumped to the database as `-1` and loaded as `:unlimited` to
  keep compatibility with the rest of the codebase.
  """

  use Ecto.Type

  def type, do: :integer

  def cast(-1), do: {:ok, :unlimited}
  def cast(:unlimited), do: {:ok, :unlimited}
  def cast("unlimited"), do: {:ok, :unlimited}
  def cast(other), do: Ecto.Type.cast(:integer, other)

  def load(-1), do: {:ok, :unlimited}
  def load(other), do: Ecto.Type.load(:integer, other)

  def dump(:unlimited), do: {:ok, -1}
  def dump(other), do: Ecto.Type.dump(:integer, other)

  def render_form(_conn, changeset, form, field, _options) do
    {:ok, value} = changeset |> Ecto.Changeset.get_field(field) |> dump()

    [
      {:safe, ~s(<div class="form-group">)},
      Phoenix.HTML.Form.label(form, field),
      Phoenix.HTML.Form.number_input(form, field,
        class: "form-control",
        name: "#{form.name}[#{field}]",
        id: "#{form.name}_#{field}",
        value: value,
        min: -1
      ),
      {:safe, ~s(<p class="help_text">Use -1 for unlimited.</p>)},
      {:safe, ~s(</div>)}
    ]
  end
end
