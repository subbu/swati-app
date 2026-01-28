defmodule Swati.Repo.Migrations.SeedBillingPlans do
  use Ecto.Migration

  def up do
    now = DateTime.utc_now()

    plans = [
      %{
        code: "starter",
        name: "Starter",
        amount: 49_900,
        currency: "INR",
        provider_plan_id: "plan_S7yIQ3Y3D5NXUf",
        entitlements: %{
          "max_phone_numbers" => 1,
          "max_integrations" => 1,
          "included_call_minutes" => 100
        }
      },
      %{
        code: "smart",
        name: "Smart",
        amount: 149_900,
        currency: "INR",
        provider_plan_id: "plan_S7yJ5AeEvMaiDR",
        entitlements: %{
          "max_phone_numbers" => 3,
          "max_integrations" => 3,
          "included_call_minutes" => 500
        }
      },
      %{
        code: "intelligent",
        name: "Intelligent",
        amount: 299_900,
        currency: "INR",
        provider_plan_id: "plan_S7yVLR6xDQddwV",
        entitlements: %{
          "max_phone_numbers" => 10,
          "max_integrations" => 10,
          "included_call_minutes" => 2000
        }
      }
    ]

    Enum.each(plans, fn plan ->
      id = Ecto.UUID.generate()

      execute("""
      INSERT INTO billing_plans (id, code, name, amount, currency, entitlements, status, inserted_at, updated_at)
      VALUES (
        '#{id}',
        '#{plan.code}',
        '#{plan.name}',
        #{plan.amount},
        '#{plan.currency}',
        '#{Jason.encode!(plan.entitlements)}',
        'active',
        '#{DateTime.to_iso8601(now)}',
        '#{DateTime.to_iso8601(now)}'
      )
      ON CONFLICT (code) DO UPDATE SET
        name = EXCLUDED.name,
        amount = EXCLUDED.amount,
        currency = EXCLUDED.currency,
        entitlements = EXCLUDED.entitlements,
        updated_at = EXCLUDED.updated_at
      """)

      execute("""
      INSERT INTO billing_plan_providers (id, plan_id, provider, provider_plan_id, inserted_at, updated_at)
      VALUES (
        '#{Ecto.UUID.generate()}',
        '#{id}',
        'razorpay',
        '#{plan.provider_plan_id}',
        '#{DateTime.to_iso8601(now)}',
        '#{DateTime.to_iso8601(now)}'
      )
      ON CONFLICT (provider, provider_plan_id) DO NOTHING
      """)
    end)
  end

  def down do
    execute("DELETE FROM billing_plan_providers WHERE provider = 'razorpay'")
    execute("DELETE FROM billing_plans WHERE code IN ('starter', 'smart', 'intelligent')")
  end
end
