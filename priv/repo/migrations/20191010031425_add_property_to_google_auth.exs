defmodule Plausible.Repo.Migrations.AddPropertyToGoogleAuth do
  use Ecto.Migration
  use Plausible.Repo

  def change do
    alter table(:google_auth) do
      add :property, :text
    end

    flush()

    for auth <- Repo.all(Plausible.Site.GoogleAuth) do
      auth = Repo.preload(auth, :site)
      property = "https://#{auth.site.domain}"
      Plausible.Site.GoogleAuth.set_property(auth, %{property: property})
      |> Repo.update!
    end
  end
end
