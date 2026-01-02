defmodule SwatiWeb.PhoneNumbersLive.Index do
  use SwatiWeb, :live_view

  alias Swati.Agents
  alias Swati.Telephony

  @default_country_iso "IN"
  @simulate_flag :simulate_number_purchase

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="space-y-8">
        <div class="flex flex-col gap-4 md:flex-row md:items-center md:justify-between">
          <div>
            <h1 class="text-2xl font-semibold">Phone numbers</h1>
          </div>
          <div class="flex items-center gap-3">
            <.button
              class="btn btn-primary"
              phx-click={Fluxon.open_dialog("buy-number-sheet") |> JS.push("open-buy-sheet")}
            >
              Buy new number
            </.button>
          </div>
        </div>

        <section class="rounded-2xl border border-base-300 bg-base-100 p-6 space-y-6">
          <div class="flex flex-col gap-2 md:flex-row md:items-center md:justify-between">
            <div>
              <h2 class="text-lg font-semibold">Provisioned numbers</h2>
            </div>
          </div>

          <.table>
            <.table_head>
              <:col>Number</:col>
              <:col>Status</:col>
              <:col>Agent</:col>
              <:col>Action</:col>
            </.table_head>
            <.table_body>
              <.table_row :for={number <- @phone_numbers} id={"phone-number-#{number.id}"}>
                <:cell class="font-medium">{format_number(number.e164)}</:cell>
                <:cell>
                  <.badge color={status_color(number.status)} variant="soft">{number.status}</.badge>
                </:cell>
                <:cell>
                  <.form
                    for={@assign_form}
                    id={"assign-form-#{number.id}"}
                    phx-change="assign"
                  >
                    <.input
                      type="hidden"
                      name="assign[phone_number_id]"
                      value={number.id}
                    />
                    <.select
                      name="assign[agent_id]"
                      options={@agent_assign_options}
                      value={number.inbound_agent_id || ""}
                    />
                  </.form>
                </:cell>
                <:cell>
                  <.form
                    for={@action_form}
                    id={"action-form-#{number.id}"}
                    phx-change="action"
                  >
                    <.input
                      type="hidden"
                      name="action[phone_number_id]"
                      value={number.id}
                    />
                    <.select
                      name="action[type]"
                      options={action_options(number)}
                      value=""
                    />
                  </.form>
                </:cell>
              </.table_row>
            </.table_body>
          </.table>
        </section>
      </div>

      <.sheet
        id="buy-number-sheet"
        placement="right"
        class="w-full max-w-xl"
        open={@buy_sheet_open}
        on_close={JS.push("close-buy-sheet")}
      >
        <div class="flex h-full flex-col">
          <div class="flex items-start justify-between gap-4 border-b border-base-200 p-6">
            <div>
              <h3 class="text-lg font-semibold">Buy a number</h3>
              <p class="text-sm text-base-content/70">Plivo</p>
            </div>
            <.button
              type="button"
              class="btn btn-ghost btn-sm"
              phx-click={Fluxon.close_dialog("buy-number-sheet") |> JS.push("close-buy-sheet")}
            >
              <.icon name="hero-x-mark" class="size-4" />
            </.button>
          </div>

          <div class="flex-1 space-y-6 overflow-y-auto p-6">
            <section class="space-y-3">
              <h4 class="text-sm font-semibold uppercase tracking-wide text-base-content/60">
                Search numbers
              </h4>
              <.form for={@search_form} id="number-search" phx-submit="search_numbers">
                <div class="grid gap-4 md:grid-cols-2">
                  <.input
                    name="search[pattern]"
                    label="Pattern"
                    value={Map.get(@search_params, "pattern", "")}
                  />
                  <.select
                    name="search[region_city]"
                    label="City"
                    options={@city_options}
                    value={Map.get(@search_params, "region_city", "")}
                  />
                </div>
                <div class="flex items-center justify-end pt-2">
                  <.button type="submit" class="btn btn-primary">Search</.button>
                </div>
              </.form>
            </section>

            <section class="space-y-3">
              <h4 class="text-sm font-semibold uppercase tracking-wide text-base-content/60">
                Purchase settings
              </h4>
              <.form for={@buy_settings_form} id="buy-settings" phx-change="update_buy_settings">
                <div class="grid gap-4 md:grid-cols-2">
                  <.select
                    name="settings[agent_id]"
                    label="Assign agent"
                    options={@agent_assign_options}
                    value={Map.get(@buy_settings, "agent_id", "")}
                  />
                  <.checkbox
                    name="settings[auto_activate]"
                    label="Activate after purchase"
                    checked={Map.get(@buy_settings, "auto_activate", false)}
                  />
                </div>
              </.form>
            </section>

            <section class="space-y-4">
              <div class="flex items-center justify-between">
                <h4 class="text-sm font-semibold uppercase tracking-wide text-base-content/60">
                  Available numbers
                </h4>
              </div>

              <div
                :if={@available_numbers == []}
                class="rounded-xl border border-dashed border-base-300 p-6 text-sm text-base-content/60"
              >
                No available numbers.
              </div>

              <div class="space-y-3">
                <div
                  :for={number <- @available_numbers}
                  id={available_dom_id(number)}
                  class="rounded-xl border border-base-200 bg-base-100 p-4"
                >
                  <div class="flex flex-col gap-4 md:flex-row md:items-center md:justify-between">
                    <div class="space-y-1">
                      <p class="text-base font-semibold">{format_number(number.number)}</p>
                      <p class="text-xs text-base-content/60">
                        {number.city || ""}
                        <%= if number.city && number.region do %>
                          <span>·</span>
                        <% end %>
                        {number.region || ""}
                        <%= if number.region && number.country do %>
                          <span>·</span>
                        <% end %>
                        {number.country || ""}
                      </p>
                      <p class="text-xs text-base-content/50">{number_label(number)}</p>
                    </div>
                    <div class="flex items-center">
                      <.button
                        class="btn btn-primary btn-sm"
                        phx-click="buy_number"
                        phx-value-number={number.number}
                      >
                        Buy
                      </.button>
                      <.button
                        :if={@simulate_enabled}
                        class="btn btn-ghost btn-sm ml-2"
                        phx-click="simulate_purchase"
                        phx-value-number={number.number}
                      >
                        Simulate
                      </.button>
                    </div>
                  </div>
                </div>
              </div>
              <div
                :if={show_pagination?(@available_meta)}
                class="flex items-center justify-between pt-2"
              >
                <p class="text-xs text-base-content/60">
                  Page {pagination_state(@available_meta).page} of {pagination_state(@available_meta).total_pages}
                </p>
                <div class="flex items-center gap-2">
                  <.button
                    class="btn btn-ghost btn-sm"
                    phx-click="page_prev"
                    disabled={!pagination_state(@available_meta).has_prev}
                  >
                    Prev
                  </.button>
                  <.button
                    class="btn btn-ghost btn-sm"
                    phx-click="page_next"
                    disabled={!pagination_state(@available_meta).has_next}
                  >
                    Next
                  </.button>
                </div>
              </div>
            </section>
          </div>
        </div>
      </.sheet>

      <.modal
        id="purchase-success-modal"
        class="w-full max-w-lg p-0 bg-transparent shadow-none rounded-none"
        open={@purchase_modal_open}
        on_close={JS.push("close-purchase-modal")}
        hide_close_button
      >
        <div class="relative overflow-hidden p-6">
          <div class="confetti-burst" aria-hidden="true">
            <span
              class="confetti-piece confetti-amber"
              style="--confetti-left: 6%; --confetti-delay: 0ms;"
            >
            </span>
            <span
              class="confetti-piece confetti-sky"
              style="--confetti-left: 18%; --confetti-delay: 120ms;"
            >
            </span>
            <span
              class="confetti-piece confetti-rose"
              style="--confetti-left: 32%; --confetti-delay: 60ms;"
            >
            </span>
            <span
              class="confetti-piece confetti-lime"
              style="--confetti-left: 48%; --confetti-delay: 180ms;"
            >
            </span>
            <span
              class="confetti-piece confetti-violet"
              style="--confetti-left: 62%; --confetti-delay: 90ms;"
            >
            </span>
            <span
              class="confetti-piece confetti-cyan"
              style="--confetti-left: 76%; --confetti-delay: 210ms;"
            >
            </span>
            <span
              class="confetti-piece confetti-orange"
              style="--confetti-left: 88%; --confetti-delay: 150ms;"
            >
            </span>
          </div>

          <div class="flex items-center gap-3">
            <.icon name="hero-check-circle" class="size-6 text-success" />
            <h3 class="text-lg font-semibold dark:text-zinc-100">Number ready</h3>
          </div>

          <p class="text-zinc-500 dark:text-zinc-400 mt-2">
            {format_number(Map.get(@purchase_summary || %{}, :number))}
            <%= if Map.get(@purchase_summary || %{}, :region) ||
                   Map.get(@purchase_summary || %{}, :country) do %>
              <span>·</span>
            <% end %>
            {Map.get(@purchase_summary || %{}, :region, "")}
            <%= if Map.get(@purchase_summary || %{}, :region) &&
                   Map.get(@purchase_summary || %{}, :country) do %>
              <span>·</span>
            <% end %>
            {Map.get(@purchase_summary || %{}, :country, "")}
            <%= if Map.get(@purchase_summary || %{}, :simulated) do %>
              <span class="text-warning"> (simulation)</span>
            <% end %>
          </p>

          <div class="flex justify-end mt-6">
            <.button
              variant="solid"
              color="primary"
              phx-click={
                Fluxon.close_dialog("purchase-success-modal") |> JS.push("close-purchase-modal")
              }
            >
              Done
            </.button>
          </div>
        </div>
      </.modal>
    </Layouts.app>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    tenant = socket.assigns.current_scope.tenant

    agents = Agents.list_agents(tenant.id)
    phone_numbers = Telephony.list_phone_numbers(tenant.id)

    search_params = %{
      "country_iso" => @default_country_iso,
      "region_city" => "",
      "pattern" => ""
    }

    buy_settings = %{"agent_id" => "", "auto_activate" => false}

    {:ok,
     socket
     |> assign(:agents, agents)
     |> assign(:phone_numbers, phone_numbers)
     |> assign(:default_country_iso, @default_country_iso)
     |> assign(:search_params, search_params)
     |> assign(:buy_settings, buy_settings)
     |> assign(:available_numbers, [])
     |> assign(:available_meta, nil)
     |> assign(:buy_sheet_open, false)
     |> assign(:purchase_modal_open, false)
     |> assign(:purchase_summary, nil)
     |> assign(:simulate_enabled, FunWithFlags.enabled?(@simulate_flag))
     |> assign(:agent_assign_options, agent_assign_options(agents))
     |> assign(:city_options, city_options())
     |> assign(:search_form, to_form(search_params, as: :search))
     |> assign(:buy_settings_form, to_form(buy_settings, as: :settings))
     |> assign(:assign_form, to_form(%{}, as: :assign))
     |> assign(:action_form, to_form(%{}, as: :action))}
  end

  @impl true
  def handle_event("open-buy-sheet", _params, socket) do
    {:noreply, assign(socket, :buy_sheet_open, true)}
  end

  @impl true
  def handle_event("close-buy-sheet", _params, socket) do
    {:noreply, assign(socket, :buy_sheet_open, false)}
  end

  @impl true
  def handle_event("close-purchase-modal", _params, socket) do
    {:noreply, socket |> assign(:purchase_modal_open, false) |> assign(:purchase_summary, nil)}
  end

  @impl true
  def handle_event("assign", %{"assign" => params}, socket) do
    tenant = socket.assigns.current_scope.tenant
    actor = socket.assigns.current_scope.user
    phone_number_id = Map.get(params, "phone_number_id")
    agent_id = Map.get(params, "agent_id")

    with true <- is_binary(phone_number_id),
         phone_number <- Telephony.get_phone_number!(tenant.id, phone_number_id),
         {:ok, _} <-
           Telephony.assign_inbound_agent(
             phone_number,
             normalize_agent_id(agent_id, tenant),
             actor
           ) do
      {:noreply,
       socket
       |> put_flash(:info, "Agent assignment updated.")
       |> refresh_data()}
    else
      _ -> {:noreply, put_flash(socket, :error, "Assignment failed.")}
    end
  end

  @impl true
  def handle_event("action", %{"action" => params}, socket) do
    tenant = socket.assigns.current_scope.tenant
    actor = socket.assigns.current_scope.user
    phone_number_id = Map.get(params, "phone_number_id")
    action = Map.get(params, "type")

    if is_binary(phone_number_id) and is_binary(action) and action != "" do
      phone_number = Telephony.get_phone_number!(tenant.id, phone_number_id)

      case action do
        "activate" ->
          respond_action(
            socket,
            Telephony.activate_phone_number(phone_number, actor),
            "Number activated."
          )

        "suspend" ->
          respond_action(
            socket,
            Telephony.suspend_phone_number(phone_number, actor),
            "Number suspended."
          )

        _ ->
          {:noreply, socket}
      end
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("search_numbers", %{"search" => params}, socket) do
    normalized = normalize_search_params(params)
    params_with_offset = Map.put(normalized, "offset", "0")

    case Telephony.search_available_numbers(params_with_offset) do
      {:ok, response} ->
        numbers = normalize_available_numbers(response)
        meta = normalize_meta(response)

        {:noreply,
         socket
         |> assign(:available_numbers, numbers)
         |> assign(:search_params, normalized)
         |> assign(:search_form, to_form(normalized, as: :search))
         |> assign(:available_meta, meta)}

      {:error, reason} ->
        {:noreply, socket |> put_flash(:error, "Search failed: #{format_reason(reason)}")}
    end
  end

  @impl true
  def handle_event("update_buy_settings", %{"settings" => params}, socket) do
    settings = %{
      "agent_id" => Map.get(params, "agent_id", ""),
      "auto_activate" => Map.get(params, "auto_activate") == "true"
    }

    {:noreply,
     socket
     |> assign(:buy_settings, settings)
     |> assign(:buy_settings_form, to_form(settings, as: :settings))}
  end

  @impl true
  def handle_event("page_next", _params, socket) do
    socket = paginate_search(socket, :next)
    {:noreply, socket}
  end

  @impl true
  def handle_event("page_prev", _params, socket) do
    socket = paginate_search(socket, :prev)
    {:noreply, socket}
  end

  @impl true
  def handle_event("buy_number", %{"number" => number}, socket) do
    tenant = socket.assigns.current_scope.tenant
    actor = socket.assigns.current_scope.user
    available = Enum.find(socket.assigns.available_numbers, &(&1.number == number))

    if available do
      attrs = %{
        "e164" => number,
        "country" => Map.get(socket.assigns.search_params, "country_iso", @default_country_iso),
        "region" => available.region || available.city
      }

      case Telephony.provision_phone_number(tenant.id, attrs, actor) do
        {:ok, phone_number} ->
          socket = maybe_assign_agent(socket, phone_number, tenant, actor)
          socket = maybe_activate_number(socket, phone_number, actor)
          socket = maybe_activate_for_assigned_agent(socket, phone_number, actor)

          summary = %{
            number: phone_number.e164,
            country: phone_number.country,
            region: phone_number.region,
            simulated: false
          }

          {:noreply,
           socket
           |> put_flash(:info, "Number purchased.")
           |> refresh_data()
           |> assign(:buy_sheet_open, false)
           |> assign(:purchase_summary, summary)
           |> assign(:purchase_modal_open, true)}

        {:error, reason} ->
          {:noreply, put_flash(socket, :error, "Purchase failed: #{format_reason(reason)}")}
      end
    else
      {:noreply, put_flash(socket, :error, "Selected number not found.")}
    end
  end

  @impl true
  def handle_event("simulate_purchase", %{"number" => number}, socket) do
    if FunWithFlags.enabled?(@simulate_flag) do
      summary = %{
        number: number,
        country: Map.get(socket.assigns.search_params, "country_iso", @default_country_iso),
        region: Map.get(socket.assigns.search_params, "region_city"),
        simulated: true
      }

      {:noreply,
       socket
       |> assign(:buy_sheet_open, false)
       |> assign(:purchase_summary, summary)
       |> assign(:purchase_modal_open, true)}
    else
      {:noreply, put_flash(socket, :error, "Simulation unavailable.")}
    end
  end

  defp respond_action(socket, {:ok, _}, message) do
    {:noreply,
     socket
     |> put_flash(:info, message)
     |> refresh_data()}
  end

  defp respond_action(socket, {:error, reason}, _message) do
    {:noreply, put_flash(socket, :error, "Action failed: #{format_reason(reason)}")}
  end

  defp refresh_data(socket) do
    tenant = socket.assigns.current_scope.tenant
    agents = Agents.list_agents(tenant.id)
    phone_numbers = Telephony.list_phone_numbers(tenant.id)

    socket
    |> assign(:agents, agents)
    |> assign(:phone_numbers, phone_numbers)
    |> assign(:agent_assign_options, agent_assign_options(agents))
  end

  defp maybe_assign_agent(socket, phone_number, tenant, actor) do
    agent_id = Map.get(socket.assigns.buy_settings, "agent_id")

    if is_binary(agent_id) and agent_id != "" do
      agent = Agents.get_agent!(tenant.id, agent_id)

      case Telephony.assign_inbound_agent(phone_number, agent.id, actor) do
        {:ok, _} -> socket
        {:error, _} -> put_flash(socket, :error, "Agent assignment failed.")
      end
    else
      socket
    end
  end

  defp maybe_activate_number(socket, phone_number, actor) do
    auto_activate = Map.get(socket.assigns.buy_settings, "auto_activate", false)

    if auto_activate do
      case Telephony.activate_phone_number(phone_number, actor) do
        {:ok, _} -> socket
        {:error, _} -> put_flash(socket, :error, "Activation failed.")
      end
    else
      socket
    end
  end

  defp maybe_activate_for_assigned_agent(socket, phone_number, actor) do
    agent_id = Map.get(socket.assigns.buy_settings, "agent_id")
    auto_activate = Map.get(socket.assigns.buy_settings, "auto_activate", false)

    if is_binary(agent_id) and agent_id != "" and not auto_activate do
      case Telephony.activate_phone_number(phone_number, actor) do
        {:ok, _} -> socket
        {:error, _} -> put_flash(socket, :error, "Activation failed.")
      end
    else
      socket
    end
  end

  defp normalize_agent_id("", _tenant), do: nil
  defp normalize_agent_id(nil, _tenant), do: nil
  defp normalize_agent_id(agent_id, tenant), do: Agents.get_agent!(tenant.id, agent_id).id

  defp normalize_search_params(params) do
    params =
      params
      |> Map.new(fn {key, value} -> {to_string(key), value} end)

    %{
      "country_iso" => @default_country_iso,
      "pattern" => empty_to_nil(Map.get(params, "pattern")),
      "region_city" => empty_to_nil(Map.get(params, "region_city")),
      "limit" => "10"
    }
    |> Enum.reject(fn {_key, value} -> is_nil(value) end)
    |> Map.new()
  end

  defp empty_to_nil(nil), do: nil

  defp empty_to_nil(value) when is_binary(value) do
    trimmed = String.trim(value)
    if trimmed == "", do: nil, else: trimmed
  end

  defp normalize_available_numbers(response) when is_map(response) do
    objects =
      Map.get(response, "objects") || Map.get(response, :objects) ||
        Map.get(response, "numbers") || Map.get(response, :numbers) || []

    Enum.map(List.wrap(objects), &normalize_available_number/1)
  end

  defp normalize_available_numbers(_), do: []

  defp normalize_available_number(object) when is_map(object) do
    %{
      number: fetch_value(object, ["number", :number]),
      country: fetch_value(object, ["country", :country]),
      region: fetch_value(object, ["region", :region]),
      city: fetch_value(object, ["city", :city]),
      type: fetch_value(object, ["type", :type]),
      sub_type: fetch_value(object, ["sub_type", :sub_type]),
      monthly_rental_rate: fetch_value(object, ["monthly_rental_rate", :monthly_rental_rate]),
      setup_rate: fetch_value(object, ["setup_rate", :setup_rate]),
      voice_enabled: fetch_value(object, ["voice_enabled", :voice_enabled]),
      sms_enabled: fetch_value(object, ["sms_enabled", :sms_enabled]),
      mms_enabled: fetch_value(object, ["mms_enabled", :mms_enabled]),
      restriction: fetch_value(object, ["restriction", :restriction]),
      restriction_text: fetch_value(object, ["restriction_text", :restriction_text])
    }
  end

  defp normalize_available_number(_), do: %{}

  defp normalize_meta(response) when is_map(response) do
    meta = Map.get(response, "meta") || Map.get(response, :meta) || %{}

    %{
      limit: to_int(Map.get(meta, "limit") || Map.get(meta, :limit), 10),
      offset: to_int(Map.get(meta, "offset") || Map.get(meta, :offset), 0),
      total_count: to_int(Map.get(meta, "total_count") || Map.get(meta, :total_count), 0)
    }
  end

  defp normalize_meta(_), do: %{limit: 10, offset: 0, total_count: 0}

  defp paginate_search(socket, direction) do
    meta = socket.assigns.available_meta
    params = socket.assigns.search_params || %{}

    if show_pagination?(meta) do
      limit = meta.limit
      offset = meta.offset

      new_offset =
        case direction do
          :next -> min(offset + limit, max(meta.total_count - limit, 0))
          :prev -> max(offset - limit, 0)
        end

      case Telephony.search_available_numbers(Map.put(params, "offset", new_offset)) do
        {:ok, response} ->
          socket
          |> assign(:available_numbers, normalize_available_numbers(response))
          |> assign(:available_meta, normalize_meta(response))

        {:error, reason} ->
          put_flash(socket, :error, "Search failed: #{format_reason(reason)}")
      end
    else
      socket
    end
  end

  defp show_pagination?(%{total_count: total, limit: limit}) when is_integer(total) do
    total > limit
  end

  defp show_pagination?(_), do: false

  defp pagination_state(%{total_count: total, limit: limit, offset: offset})
       when is_integer(total) and is_integer(limit) and is_integer(offset) do
    page = div(offset, limit) + 1
    total_pages = ceil_div(total, limit)

    %{
      page: page,
      total_pages: total_pages,
      has_prev: offset > 0,
      has_next: offset + limit < total
    }
  end

  defp pagination_state(_), do: %{page: 1, total_pages: 1, has_prev: false, has_next: false}

  defp ceil_div(total, limit) when limit > 0 do
    div(total + limit - 1, limit)
  end

  defp to_int(nil, fallback), do: fallback

  defp to_int(value, _fallback) when is_integer(value), do: value

  defp to_int(value, fallback) when is_binary(value) do
    case Integer.parse(value) do
      {int, _} -> int
      :error -> fallback
    end
  end

  defp to_int(_value, fallback), do: fallback

  defp fetch_value(map, keys) do
    Enum.find_value(keys, fn key -> Map.get(map, key) end)
  end

  defp agent_assign_options(agents) do
    [{"Unassigned", ""} | Enum.map(agents, fn agent -> {agent.name, agent.id} end)]
  end

  defp city_options do
    [
      {"All", ""},
      {"Mumbai", "Mumbai"},
      {"Bangalore", "Bangalore"}
    ]
  end

  defp action_options(number) do
    base = [{"Actions", ""}]

    if number.status in [:active, "active"] do
      base ++ [{"Suspend", "suspend"}]
    else
      base ++ [{"Activate", "activate"}]
    end
  end

  defp number_label(number) do
    type = number.type || ""
    subtype = number.sub_type || ""

    case {type, subtype} do
      {"", ""} -> "Number"
      {_, ""} -> type
      {"", _} -> subtype
      _ -> "#{type} · #{subtype}"
    end
  end

  defp available_dom_id(number) do
    safe =
      number.number
      |> to_string()
      |> String.replace(~r/[^a-zA-Z0-9_-]/, "-")

    "available-number-#{safe}"
  end

  defp format_reason(reason) when is_binary(reason), do: reason
  defp format_reason({status, _body}) when is_integer(status), do: "HTTP #{status}"
  defp format_reason(%{message: message}) when is_binary(message), do: message
  defp format_reason(_reason), do: "unexpected error"

  defp format_number(nil), do: "—"

  defp format_number(value) when is_binary(value) do
    trimmed = String.trim(value)
    prefix = if String.starts_with?(trimmed, "+"), do: "+", else: ""
    digits = String.replace(trimmed, ~r/[^0-9]/, "")

    if String.length(digits) == 12 and String.starts_with?(digits, "91") do
      country = String.slice(digits, 0, 2)
      area = String.slice(digits, 2, 2)
      block1 = String.slice(digits, 4, 4)
      block2 = String.slice(digits, 8, 4)
      "+#{country} #{area} #{block1} #{block2}"
    else
      format_number_fallback(prefix, digits)
    end
  end

  defp format_number_fallback(prefix, digits) do
    if String.length(digits) <= 4 do
      prefix <> digits
    else
      {rest, last4} = String.split_at(digits, -4)
      groups = chunk_from_right(rest, 3)

      [prefix <> Enum.join(groups, " "), last4]
      |> Enum.reject(&(&1 == ""))
      |> Enum.join(" ")
    end
  end

  defp chunk_from_right(value, size) do
    value
    |> String.graphemes()
    |> Enum.reverse()
    |> Enum.chunk_every(size)
    |> Enum.map(&Enum.reverse/1)
    |> Enum.reverse()
    |> Enum.map(&Enum.join/1)
  end

  defp status_color(:active), do: "success"
  defp status_color("active"), do: "success"
  defp status_color(:provisioned), do: "warning"
  defp status_color("provisioned"), do: "warning"
  defp status_color(:suspended), do: "danger"
  defp status_color("suspended"), do: "danger"
  defp status_color(:released), do: "neutral"
  defp status_color("released"), do: "neutral"
  defp status_color(_), do: "neutral"
end
