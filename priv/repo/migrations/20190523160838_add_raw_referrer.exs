defmodule Plausible.Repo.Migrations.AddRawReferrer do
  use Ecto.Migration

  def change do
    alter table(:pageviews) do
      add :raw_referrer, :text
    end

    flush()

    execute "UPDATE pageviews set raw_referrer = referrer"

    flush()

    execute """
      UPDATE pageviews SET referrer = split_part(split_part(regexp_replace(regexp_replace(regexp_replace(raw_referrer, '^https://', ''), '^http://', ''), '^www\.', ''), '?', 1), '#', 1)
    """
  end
end
