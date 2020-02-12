defmodule Plausible.Repo.Migrations.AddInitialSourceAndReferrerToEvents do
  use Ecto.Migration

  def change do
    alter table(:events) do
      add :initial_referrer, :text
      add :initial_referrer_source, :text
    end

    execute "UPDATE events SET initial_referrer=referrer, initial_referrer_source=referrer_source"
    execute "UPDATE events SET referrer=null, referrer_source=null WHERE new_visitor=false"
  end
end
