defmodule SwatiWeb.PhoneNumbersLive.Index do
  use SwatiWeb, :live_view

  alias Swati.Agents
  alias Swati.Telephony

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="space-y-8">
        <div>
          <h1 class="text-2xl font-semibold">Phone numbers</h1>
          <p class="text-sm text-base-content/70">Provision, assign, and activate inbound numbers.</p>
        </div>

        <section class="rounded-2xl border border-base-300 bg-base-100 p-6 space-y-4">
          <h2 class="text-lg font-semibold">Provision number</h2>
          <.form for={@provision_form} id="provision-form" phx-submit="provision">
            <div class="grid gap-4 md:grid-cols-3">
              <.input name="provision[e164]" label="E.164" required />
              <.input name="provision[country]" label="Country" required />
              <.input name="provision[region]" label="Region" />
            </div>
            <div class="flex justify-end">
              <.button type="submit">Provision</.button>
            </div>
          </.form>
        </section>

        <section class="rounded-2xl border border-base-300 bg-base-100 p-6 space-y-4">
          <h2 class="text-lg font-semibold">Assign inbound agent</h2>
          <.form for={@assign_form} id="assign-form" phx-submit="assign">
            <div class="grid gap-4 md:grid-cols-3">
              <.select
                name="assign[phone_number_id]"
                label="Phone number"
                options={@phone_number_options}
              />
              <.select name="assign[agent_id]" label="Agent" options={@agent_options} />
            </div>
            <div class="flex justify-end">
              <.button type="submit">Assign</.button>
            </div>
          </.form>
        </section>

        <section class="rounded-2xl border border-base-300 bg-base-100 p-6 space-y-4">
          <h2 class="text-lg font-semibold">Activate number</h2>
          <.form for={@activate_form} id="activate-form" phx-submit="activate">
            <div class="grid gap-4 md:grid-cols-3">
              <.select
                name="activate[phone_number_id]"
                label="Phone number"
                options={@phone_number_options}
              />
            </div>
            <div class="flex justify-end">
              <.button type="submit">Activate</.button>
            </div>
          </.form>
        </section>

        <.table>
          <.table_head>
            <:col>E.164</:col>
            <:col>Status</:col>
            <:col>Agent</:col>
            <:col>Provider</:col>
            <:col>Answer URL</:col>
          </.table_head>
          <.table_body>
            <.table_row :for={number <- @phone_numbers}>
              <:cell class="font-medium">{number.e164}</:cell>
              <:cell>
                <.badge color={status_color(number.status)} variant="soft">{number.status}</.badge>
              </:cell>
              <:cell>{agent_name(number, @agents)}</:cell>
              <:cell>{number.provider}</:cell>
              <:cell class="text-xs text-base-content/60">{number.answer_url || "—"}</:cell>
            </.table_row>
          </.table_body>
        </.table>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    tenant = socket.assigns.current_scope.tenant

    agents = Agents.list_agents(tenant.id)
    phone_numbers = Telephony.list_phone_numbers(tenant.id)

    {:ok,
     socket
     |> assign(:agents, agents)
     |> assign(:phone_numbers, phone_numbers)
     |> assign(:agent_options, agent_options(agents))
     |> assign(:phone_number_options, phone_number_options(phone_numbers))
     |> assign(:provision_form, to_form(%{}, as: :provision))
     |> assign(:assign_form, to_form(%{}, as: :assign))
     |> assign(:activate_form, to_form(%{}, as: :activate))}
  end

  @impl true
  def handle_event("provision", %{"provision" => params}, socket) do
    tenant = socket.assigns.current_scope.tenant

    case Telephony.provision_phone_number(tenant.id, params, socket.assigns.current_scope.user) do
      {:ok, _phone_number} ->
        {:noreply,
         socket
         |> put_flash(:info, "Number provisioned.")
         |> refresh_data()}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, inspect(reason))}
    end
  end

  @impl true
  def handle_event("assign", %{"assign" => params}, socket) do
    with phone_number_id when is_binary(phone_number_id) <- Map.get(params, "phone_number_id"),
         agent_id when is_binary(agent_id) <- Map.get(params, "agent_id"),
         phone_number <- Telephony.get_phone_number!(phone_number_id),
         {:ok, _} <-
           Telephony.assign_inbound_agent(
             phone_number,
             agent_id,
             socket.assigns.current_scope.user
           ) do
      {:noreply,
       socket
       |> put_flash(:info, "Agent assigned.")
       |> refresh_data()}
    else
      _ -> {:noreply, put_flash(socket, :error, "Assignment failed.")}
    end
  end

  @impl true
  def handle_event("activate", %{"activate" => params}, socket) do
    phone_number_id = Map.get(params, "phone_number_id")

    if is_binary(phone_number_id) do
      case Telephony.get_phone_number!(phone_number_id)
           |> Telephony.activate_phone_number(socket.assigns.current_scope.user) do
        {:ok, _phone_number} ->
          {:noreply,
           socket
           |> put_flash(:info, "Number activated.")
           |> refresh_data()}

        {:error, reason} ->
          {:noreply, put_flash(socket, :error, inspect(reason))}
      end
    else
      {:noreply, put_flash(socket, :error, "Select a phone number.")}
    end
  end

  defp refresh_data(socket) do
    tenant = socket.assigns.current_scope.tenant
    agents = Agents.list_agents(tenant.id)
    phone_numbers = Telephony.list_phone_numbers(tenant.id)

    socket
    |> assign(:agents, agents)
    |> assign(:phone_numbers, phone_numbers)
    |> assign(:agent_options, agent_options(agents))
    |> assign(:phone_number_options, phone_number_options(phone_numbers))
  end

  defp agent_options(agents) do
    Enum.map(agents, fn agent -> {agent.name, agent.id} end)
  end

  defp phone_number_options(phone_numbers) do
    Enum.map(phone_numbers, fn number -> {number.e164, number.id} end)
  end

  defp agent_name(%{inbound_agent_id: nil}, _agents), do: "—"

  defp agent_name(number, agents) do
    case Enum.find(agents, &(&1.id == number.inbound_agent_id)) do
      nil -> "—"
      agent -> agent.name
    end
  end

  defp status_color(:active), do: "success"
  defp status_color("active"), do: "success"
  defp status_color(:provisioned), do: "warning"
  defp status_color("provisioned"), do: "warning"
  defp status_color(_), do: "neutral"
end
