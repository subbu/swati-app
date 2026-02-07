defmodule Swati.Repo.Migrations.AddEmployeeProfilesAndRenameRole do
  use Ecto.Migration

  def up do
    # Rename "agent" role to "staff" to avoid confusion with AI agents
    execute "UPDATE memberships SET role = 'staff' WHERE role = 'agent'"

    alter table(:memberships) do
      add :display_name, :string
      add :title, :string
      add :phone, :string
    end
  end

  def down do
    alter table(:memberships) do
      remove :display_name
      remove :title
      remove :phone
    end

    execute "UPDATE memberships SET role = 'agent' WHERE role = 'staff'"
  end
end
