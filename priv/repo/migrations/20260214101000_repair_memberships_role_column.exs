defmodule Swati.Repo.Migrations.RepairMembershipsRoleColumn do
  use Ecto.Migration

  def up do
    execute("""
    DO $$
    BEGIN
      IF NOT EXISTS (
        SELECT 1
        FROM information_schema.columns
        WHERE table_schema = 'public'
          AND table_name = 'memberships'
          AND column_name = 'role'
      ) THEN
        ALTER TABLE memberships ADD COLUMN role varchar;
      END IF;

      IF EXISTS (
        SELECT 1
        FROM information_schema.columns
        WHERE table_schema = 'public'
          AND table_name = 'memberships'
          AND column_name = 'role_id'
      ) THEN
        UPDATE memberships AS m
        SET role = CASE lower(r.name)
          WHEN 'owner' THEN 'owner'
          WHEN 'admin' THEN 'admin'
          WHEN 'agent' THEN 'agent'
          WHEN 'member' THEN 'member'
          WHEN 'viewer' THEN 'viewer'
          WHEN 'staff' THEN 'agent'
          WHEN 'doctor' THEN 'agent'
          ELSE 'member'
        END
        FROM roles AS r
        WHERE m.role IS NULL AND r.id = m.role_id;
      END IF;

      UPDATE memberships
      SET role = 'member'
      WHERE role IS NULL;

      ALTER TABLE memberships ALTER COLUMN role SET DEFAULT 'member';
      ALTER TABLE memberships ALTER COLUMN role SET NOT NULL;
    END
    $$;
    """)
  end

  def down do
    :ok
  end
end
