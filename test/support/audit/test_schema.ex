defmodule Plausible.Audit.TestSchema do
  @moduledoc false
  use Ecto.Schema

  @derive {Plausible.Audit.Encoder, only: [:id, :name]}

  schema "tests" do
    field :name, :string
  end

  defmodule VariantWithAssociation do
    @moduledoc false
    use Ecto.Schema

    @derive {Plausible.Audit.Encoder, only: [:id, :team]}

    schema "tests" do
      belongs_to :team, Plausible.Teams.Team
    end
  end

  defmodule VariantWithAssociationAllowNotLoaded do
    @moduledoc false
    use Ecto.Schema

    @derive {Plausible.Audit.Encoder, only: [:id, :team], allow_not_loaded: [:team]}

    schema "tests" do
      belongs_to :team, Plausible.Teams.Team
    end
  end
end
