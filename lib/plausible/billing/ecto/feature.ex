defmodule Plausible.Billing.Ecto.Feature do
  @moduledoc """
  Ecto type representing a feature. Features are cast and stored in the
  database as strings and loaded as modules, for example: `"props"` is loaded
  as `Plausible.Billing.Feature.Props`.
  """

  use Ecto.Type

  def type, do: :string

  def cast(feature) when is_binary(feature) do
    found =
      Enum.find(Plausible.Billing.Feature.list(), fn mod ->
        Atom.to_string(mod.name()) == feature
      end)

    if found, do: {:ok, found}, else: :error
  end

  def cast(mod) when is_atom(mod) do
    {:ok, mod}
  end

  def load(feature) when is_binary(feature) do
    cast(feature)
  end

  def dump(mod) when is_atom(mod) do
    {:ok, Atom.to_string(mod.name())}
  end
end

defmodule Plausible.Billing.Ecto.FeatureList do
  @moduledoc """
  Ecto type representing a list of features. This is a proxy for
  `{:array, Plausible.Billing.Ecto.Feature}` and is required for Kaffy to
  render the HTML input correctly.
  """

  use Ecto.Type

  def type, do: {:array, Plausible.Billing.Ecto.Feature}
  def cast(list), do: Ecto.Type.cast(type(), list)
  def load(list), do: Ecto.Type.load(type(), list)
  def dump(list), do: Ecto.Type.dump(type(), list)

  def render_form(_conn, changeset, form, field, _options) do
    features = Ecto.Changeset.get_field(changeset, field)

    checkboxes =
      for mod <- Plausible.Billing.Feature.list(), not mod.free?() do
        [
          {:safe, ~s(<label style="padding-right: 15px;">)},
          {:safe,
           ~s(<input type="checkbox" name="#{form.name}[#{field}][]" "#{form.name}_#{field}_#{mod.name()}" value="#{mod.name()}" style="margin-right: 3px;" #{if mod in features, do: "checked", else: ""}>)},
          mod.display_name(),
          {:safe, ~s(</label>)}
        ]
      end

    [
      {:safe, ~s(<div class="form-group">)},
      {:safe, ~s(<label for="#{form.name}_#{field}">#{Phoenix.Naming.humanize(field)}</label>)},
      {:safe, ~s(<div class="form-control">)},
      checkboxes,
      {:safe, ~s(</div>)},
      {:safe, ~s(</div>)}
    ]
  end
end
