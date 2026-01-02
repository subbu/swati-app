defmodule Swati.Repo.Migrations.CreateObanJobs do
  use Ecto.Migration

  def up do
    Oban.Migrations.SQLite.up([])
  end

  def down do
    Oban.Migrations.SQLite.down([])
  end
end
