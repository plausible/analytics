defmodule Plausible.Repo.Migrations.CalcScreenSize do
  use Ecto.Migration

  def change do
    execute """
    UPDATE pageviews SET screen_size= (
    CASE
    WHEN screen_width is null THEN null
    WHEN screen_width < 576 THEN 'Mobile'
    WHEN screen_width < 992 THEN 'Tablet'
    WHEN screen_width < 1440 THEN 'Laptop'
    ELSE 'Desktop'
    END
    );
    """
  end
end
