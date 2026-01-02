defmodule SwatiWeb.OnboardingLive do
  use SwatiWeb, :live_view

  alias Swati.Agents
  alias Swati.Integrations
  alias Swati.Telephony

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="space-y-10">
        <div class="space-y-2">
          <h1 class="text-3xl font-semibold">Get your control plane live</h1>
          <p class="text-base text-base-content/70">
            Complete these steps to take your first call in minutes.
          </p>
        </div>

        <div class="grid gap-4">
          <div
            :for={step <- @steps}
            class="rounded-2xl border border-base-300 bg-base-100 p-6 flex flex-col gap-3"
          >
            <div class="flex items-start justify-between gap-4">
              <div>
                <h2 class="text-lg font-semibold">{step.title}</h2>
                <p class="text-sm text-base-content/70">{step.description}</p>
              </div>
              <.badge color={step.badge_color} variant="soft">{step.status_label}</.badge>
            </div>
            <div class="flex items-center gap-3">
              <.button :if={step.link} navigate={step.link} variant="soft">Go</.button>
              <span :if={!step.link} class="text-sm text-base-content/60">Already set</span>
            </div>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    tenant = socket.assigns.current_scope.tenant

    steps =
      [
        %{
          title: "Create Workspace",
          description: "Your tenant is ready.",
          done?: true,
          link: nil
        },
        step_for(
          "Create your first Agent",
          "Configure prompts and tools.",
          has_agents?(tenant),
          ~p"/agents/new"
        ),
        step_for(
          "Add MCP integration",
          "Connect tools and data.",
          has_integrations?(tenant),
          ~p"/integrations/new"
        ),
        step_for(
          "Provision phone number",
          "Buy or attach a number.",
          has_numbers?(tenant),
          ~p"/numbers"
        ),
        step_for(
          "Activate and test",
          "Assign an agent and activate inbound calls.",
          has_active_numbers?(tenant),
          ~p"/numbers"
        )
      ]
      |> Enum.map(&decorate_step/1)

    {:ok, assign(socket, steps: steps)}
  end

  defp step_for(title, description, done?, link) do
    %{
      title: title,
      description: description,
      done?: done?,
      link: if(done?, do: nil, else: link)
    }
  end

  defp decorate_step(step) do
    if step.done? do
      Map.merge(step, %{status_label: "Done", badge_color: "success"})
    else
      Map.merge(step, %{status_label: "Pending", badge_color: "warning"})
    end
  end

  defp has_agents?(tenant) do
    tenant && Agents.list_agents(tenant.id) != []
  end

  defp has_integrations?(tenant) do
    tenant && Integrations.list_integrations(tenant.id) != []
  end

  defp has_numbers?(tenant) do
    tenant && Telephony.list_phone_numbers(tenant.id) != []
  end

  defp has_active_numbers?(tenant) do
    if tenant do
      Telephony.list_phone_numbers(tenant.id)
      |> Enum.any?(fn number -> number.status == :active end)
    else
      false
    end
  end
end
