defmodule Swati.Repo.Migrations.AddCustomRoles do
  use Ecto.Migration

  def up do
    # 1. Create the roles table
    create table(:roles, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :name, :string, null: false
      add :permissions, :jsonb, null: false, default: "[]"
      add :is_system, :boolean, null: false, default: false
      add :tenant_id, references(:tenants, type: :binary_id, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:roles, [:tenant_id, :name])
    create index(:roles, [:tenant_id])

    # 2. Add role_id FK to memberships (nullable initially for backfill)
    alter table(:memberships) do
      add :role_id, references(:roles, type: :binary_id, on_delete: :restrict)
    end

    create index(:memberships, [:role_id])

    # 3. Backfill: create roles from existing enum values, then link memberships
    #    This is done in raw SQL for reliability during migration.
    execute """
    DO $$
    DECLARE
      t_record RECORD;
      role_record RECORD;
      owner_perms jsonb;
      admin_perms jsonb;
      staff_perms jsonb;
      member_perms jsonb;
      viewer_perms jsonb;
    BEGIN
      -- Define permission sets matching the old hardcoded matrix
      owner_perms := '["assign_cases","manage_agents","manage_billing","manage_cases","manage_channels","manage_customers","manage_integrations","manage_members","manage_roles","manage_settings","manage_trust","manage_webhooks","update_case_status","view_billing","view_cases","view_customers","view_dashboard","view_sessions"]'::jsonb;
      admin_perms := '["assign_cases","manage_agents","manage_cases","manage_channels","manage_customers","manage_integrations","manage_members","manage_roles","manage_settings","manage_trust","manage_webhooks","update_case_status","view_billing","view_cases","view_customers","view_dashboard","view_sessions"]'::jsonb;
      staff_perms := '["assign_cases","manage_cases","manage_customers","update_case_status","view_cases","view_customers","view_dashboard","view_sessions"]'::jsonb;
      member_perms := '["update_case_status","view_cases","view_dashboard","view_sessions"]'::jsonb;
      viewer_perms := '["view_cases","view_dashboard","view_sessions"]'::jsonb;

      -- For each tenant, create the 5 default roles and backfill memberships
      FOR t_record IN SELECT DISTINCT tenant_id FROM memberships LOOP
        -- Owner (system role)
        INSERT INTO roles (id, name, permissions, is_system, tenant_id, inserted_at, updated_at)
        VALUES (gen_random_uuid(), 'Owner', owner_perms, true, t_record.tenant_id, NOW(), NOW())
        RETURNING id INTO role_record;
        UPDATE memberships SET role_id = role_record.id WHERE tenant_id = t_record.tenant_id AND role = 'owner';

        -- Admin
        INSERT INTO roles (id, name, permissions, is_system, tenant_id, inserted_at, updated_at)
        VALUES (gen_random_uuid(), 'Admin', admin_perms, false, t_record.tenant_id, NOW(), NOW())
        RETURNING id INTO role_record;
        UPDATE memberships SET role_id = role_record.id WHERE tenant_id = t_record.tenant_id AND role = 'admin';

        -- Staff
        INSERT INTO roles (id, name, permissions, is_system, tenant_id, inserted_at, updated_at)
        VALUES (gen_random_uuid(), 'Staff', staff_perms, false, t_record.tenant_id, NOW(), NOW())
        RETURNING id INTO role_record;
        UPDATE memberships SET role_id = role_record.id WHERE tenant_id = t_record.tenant_id AND role = 'staff';

        -- Member
        INSERT INTO roles (id, name, permissions, is_system, tenant_id, inserted_at, updated_at)
        VALUES (gen_random_uuid(), 'Member', member_perms, false, t_record.tenant_id, NOW(), NOW())
        RETURNING id INTO role_record;
        UPDATE memberships SET role_id = role_record.id WHERE tenant_id = t_record.tenant_id AND role = 'member';

        -- Viewer
        INSERT INTO roles (id, name, permissions, is_system, tenant_id, inserted_at, updated_at)
        VALUES (gen_random_uuid(), 'Viewer', viewer_perms, false, t_record.tenant_id, NOW(), NOW())
        RETURNING id INTO role_record;
        UPDATE memberships SET role_id = role_record.id WHERE tenant_id = t_record.tenant_id AND role = 'viewer';
      END LOOP;
    END $$;
    """

    # 4. Make role_id NOT NULL now that backfill is done
    alter table(:memberships) do
      modify :role_id, :binary_id, null: false, from: {:binary_id, null: true}
    end

    # 5. Drop the old role string column
    alter table(:memberships) do
      remove :role
    end
  end

  def down do
    # Re-add the role string column
    alter table(:memberships) do
      add :role, :string, default: "member"
    end

    # Backfill role strings from the roles table
    execute """
    UPDATE memberships m
    SET role = LOWER(r.name)
    FROM roles r
    WHERE m.role_id = r.id;
    """

    alter table(:memberships) do
      modify :role, :string, null: false, from: {:string, null: true}
    end

    # Drop role_id FK
    alter table(:memberships) do
      remove :role_id
    end

    # Drop roles table
    drop table(:roles)
  end
end
