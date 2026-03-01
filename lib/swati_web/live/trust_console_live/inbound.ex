defmodule SwatiWeb.TrustConsoleLive.Inbound do
  use SwatiWeb, :live_view

  alias Swati.Inbound
  alias SwatiWeb.Formatting

  @impl true
  def mount(_params, _session, socket) do
    if Swati.Accounts.authorized?(socket.assigns.current_scope, :manage_trust) do
      tenant_id = socket.assigns.current_scope.tenant.id

      {:ok,
       socket
       |> assign(:tenant_id, tenant_id)
       |> assign(:active_tab, :inbound)
       |> assign(:filters, default_filters())
       |> assign(:selected_delivery, nil)
       |> load_data()}
    else
      {:ok,
       socket
       |> put_flash(:error, "You don't have permission to access this page.")
       |> redirect(to: ~p"/dashboard")}
    end
  end

  @impl true
  def handle_params(params, _uri, socket) do
    selected_delivery =
      case Map.get(params, "delivery_id") do
        nil -> List.first(socket.assigns.deliveries)
        "" -> List.first(socket.assigns.deliveries)
        id -> Enum.find(socket.assigns.deliveries, &(to_string(&1.id) == to_string(id)))
      end

    {:noreply, assign(socket, :selected_delivery, selected_delivery)}
  end

  @impl true
  def handle_event("filter", %{"filters" => params}, socket) do
    filters =
      socket.assigns.filters
      |> Map.merge(params)
      |> normalize_filters()

    {:noreply,
     socket
     |> assign(:filters, filters)
     |> load_data()
     |> push_patch(to: ~p"/trust/inbound")}
  end

  @impl true
  def handle_event("clear_filters", _params, socket) do
    {:noreply,
     socket
     |> assign(:filters, default_filters())
     |> load_data()
     |> push_patch(to: ~p"/trust/inbound")}
  end

  @impl true
  def handle_event("replay_delivery", %{"id" => id}, socket) do
    delivery = Inbound.get_delivery!(socket.assigns.tenant_id, id)

    case Inbound.replay_delivery(delivery) do
      {:ok, _delivery} ->
        {:noreply,
         socket
         |> put_flash(:info, "Delivery replay queued.")
         |> load_data()
         |> push_patch(to: ~p"/trust/inbound?delivery_id=#{id}")}

      {:error, :delivery_busy} ->
        {:noreply, put_flash(socket, :error, "Delivery is currently being processed.")}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, "Replay failed: #{inspect(reason)}")}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div id="trust-inbound" class="space-y-6">
        <header class="flex flex-wrap items-center justify-between gap-4 border-b border-base pb-4">
          <div>
            <h1 class="text-xl font-semibold text-foreground">Trust Console</h1>
            <p class="text-sm text-foreground-soft">
              Inbound webhook deliveries, verification outcome, routing reason, and replay controls.
            </p>
          </div>
          <.badge size="sm" variant="soft" color="info">{length(@deliveries)} deliveries</.badge>
        </header>

        <nav class="flex flex-wrap items-center gap-2 text-sm">
          <.link navigate={~p"/trust"} class={nav_class(false)}>Timeline</.link>
          <.link navigate={~p"/trust/policy"} class={nav_class(false)}>Policy</.link>
          <.link navigate={~p"/trust/reliability"} class={nav_class(false)}>Reliability</.link>
          <.link navigate={~p"/trust/rejections"} class={nav_class(false)}>Rejections</.link>
          <.link navigate={~p"/trust/inbound"} class={nav_class(true)}>Inbound deliveries</.link>
        </nav>

        <section class="rounded-base border border-base bg-base p-4 space-y-3">
          <h2 class="text-sm font-semibold text-foreground">Filters</h2>
          <.form
            for={to_form(@filters, as: :filters)}
            phx-change="filter"
            class="grid gap-3 md:grid-cols-4"
          >
            <div class="space-y-1">
              <.label for="filters_status">Status</.label>
              <select id="filters_status" name="filters[status]" class="select w-full">
                <option value="" selected={@filters["status"] == ""}>All</option>
                <option value="received" selected={@filters["status"] == "received"}>received</option>
                <option value="processing" selected={@filters["status"] == "processing"}>
                  processing
                </option>
                <option value="processed" selected={@filters["status"] == "processed"}>
                  processed
                </option>
                <option value="failed" selected={@filters["status"] == "failed"}>failed</option>
              </select>
            </div>

            <div class="space-y-1">
              <.label for="filters_connector_id">Connector</.label>
              <select id="filters_connector_id" name="filters[connector_id]" class="select w-full">
                <option value="" selected={@filters["connector_id"] == ""}>All</option>
                <option
                  :for={connector <- @connectors}
                  value={connector.id}
                  selected={to_string(@filters["connector_id"]) == to_string(connector.id)}
                >
                  {connector.name}
                </option>
              </select>
            </div>

            <.input
              name="filters[from_address]"
              value={@filters["from_address"]}
              label="From"
              placeholder="user@example.com"
            />
            <.input
              name="filters[query]"
              value={@filters["query"]}
              label="Search"
              placeholder="subject or payload text"
            />
          </.form>
          <div class="flex justify-end">
            <.button variant="ghost" phx-click="clear_filters" size="xs">Clear filters</.button>
          </div>
        </section>

        <section class="grid gap-6 xl:grid-cols-[minmax(0,1.2fr)_minmax(0,1fr)]">
          <div class="rounded-base border border-base bg-base p-4">
            <h2 class="text-sm font-semibold text-foreground">Inbound deliveries</h2>
            <div :if={@deliveries == []} class="mt-3 text-sm text-foreground-soft">
              No deliveries match current filters.
            </div>
            <div :if={@deliveries != []} class="mt-3 divide-y divide-base">
              <.link
                :for={delivery <- @deliveries}
                patch={~p"/trust/inbound?delivery_id=#{delivery.id}"}
                class={[
                  "block px-3 py-3 rounded-base",
                  if(@selected_delivery && @selected_delivery.id == delivery.id,
                    do: "bg-accent",
                    else: "hover:bg-accent/60"
                  )
                ]}
              >
                <div class="flex items-center justify-between gap-2">
                  <div class="min-w-0">
                    <div class="text-sm font-medium text-foreground truncate">
                      {delivery_subject(delivery)}
                    </div>
                    <div class="text-xs text-foreground-soft truncate">
                      {delivery_from(delivery)} -> {delivery_to(delivery)}
                    </div>
                  </div>
                  <.badge size="xs" variant="soft" color={status_color(delivery.status)}>
                    {delivery.status}
                  </.badge>
                </div>
                <div class="mt-1 text-xs text-foreground-soft">
                  {format_ts(delivery.received_at, @current_scope.tenant)} · route: {delivery_route(
                    delivery
                  )} ·
                  continuity: {delivery_continuity(delivery)}
                </div>
              </.link>
            </div>
          </div>

          <div class="rounded-base border border-base bg-base p-4 space-y-3">
            <h2 class="text-sm font-semibold text-foreground">Delivery detail</h2>
            <div :if={!@selected_delivery} class="text-sm text-foreground-soft">
              Select a delivery to inspect signature, payload, and linkage.
            </div>

            <div :if={@selected_delivery} class="space-y-3">
              <div class="text-xs text-foreground-soft">
                id: {@selected_delivery.id}
              </div>
              <div class="grid grid-cols-2 gap-2 text-xs">
                <div>
                  <span class="text-foreground-soft">status:</span>
                  <span class="text-foreground">{@selected_delivery.status}</span>
                </div>
                <div>
                  <span class="text-foreground-soft">signature:</span>
                  <span class="text-foreground">{signature_state(@selected_delivery)}</span>
                </div>
                <div>
                  <span class="text-foreground-soft">connector:</span>
                  <span class="text-foreground">
                    {@selected_delivery.connector && @selected_delivery.connector.name}
                  </span>
                </div>
                <div>
                  <span class="text-foreground-soft">processed:</span>
                  <span class="text-foreground">
                    {format_ts(@selected_delivery.processed_at, @current_scope.tenant)}
                  </span>
                </div>
              </div>

              <div class="text-xs text-foreground-soft">
                session:
                <.link
                  :if={delivery_session_id(@selected_delivery)}
                  navigate={~p"/sessions/#{delivery_session_id(@selected_delivery)}"}
                  class="link"
                >
                  {delivery_session_id(@selected_delivery)}
                </.link>
                <span :if={!delivery_session_id(@selected_delivery)}>-</span>
                · case:
                <.link
                  :if={delivery_case_id(@selected_delivery)}
                  navigate={~p"/cases/#{delivery_case_id(@selected_delivery)}"}
                  class="link"
                >
                  {delivery_case_id(@selected_delivery)}
                </.link>
                <span :if={!delivery_case_id(@selected_delivery)}>-</span>
              </div>

              <.button
                :if={replayable?(@selected_delivery)}
                variant="soft"
                size="xs"
                phx-click="replay_delivery"
                phx-value-id={@selected_delivery.id}
              >
                Replay delivery
              </.button>

              <div :if={@selected_delivery.processing_error} class="text-xs text-danger break-all">
                error: {@selected_delivery.processing_error}
              </div>

              <section class="space-y-2">
                <h3 class="text-xs font-semibold text-foreground">Normalized payload</h3>
                <pre class="overflow-auto rounded-base border border-base bg-base-100 p-2 text-[11px] leading-5">{pretty_json(@selected_delivery.normalized_payload)}</pre>
              </section>

              <section class="space-y-2">
                <h3 class="text-xs font-semibold text-foreground">Route details</h3>
                <pre class="overflow-auto rounded-base border border-base bg-base-100 p-2 text-[11px] leading-5">{pretty_json(@selected_delivery.route_details)}</pre>
              </section>
            </div>
          </div>
        </section>
      </div>
    </Layouts.app>
    """
  end

  defp load_data(socket) do
    tenant_id = socket.assigns.tenant_id
    filters = socket.assigns.filters

    socket
    |> assign(:connectors, Inbound.list_connectors(tenant_id))
    |> assign(:deliveries, Inbound.list_deliveries(tenant_id, limit: 100, filters: filters))
  end

  defp default_filters do
    %{
      "status" => "",
      "connector_id" => "",
      "from_address" => "",
      "query" => ""
    }
  end

  defp normalize_filters(filters) do
    filters
    |> Map.new(fn {key, value} -> {to_string(key), normalize_filter_value(value)} end)
    |> Map.merge(default_filters(), fn _key, current, _default -> current end)
  end

  defp normalize_filter_value(nil), do: ""
  defp normalize_filter_value(value) when is_binary(value), do: String.trim(value)
  defp normalize_filter_value(value), do: to_string(value)

  defp format_ts(nil, _tenant), do: "-"
  defp format_ts(%DateTime{} = ts, tenant), do: Formatting.datetime(ts, tenant)

  defp delivery_subject(delivery) do
    get_in(delivery.normalized_payload || %{}, ["subject"]) || "(no subject)"
  end

  defp delivery_from(delivery), do: get_in(delivery.normalized_payload || %{}, ["from"]) || "-"

  defp delivery_to(delivery) do
    delivery.normalized_payload
    |> case do
      %{"to" => to} -> List.wrap(to) |> Enum.join(", ")
      _ -> "-"
    end
  end

  defp delivery_route(delivery),
    do: get_in(delivery.route_details || %{}, ["route_reason"]) || "-"

  defp delivery_continuity(delivery) do
    delivery.route_details
    |> case do
      %{"continuity" => %{"hit" => hit, "strategy" => strategy}} -> "#{hit} (#{strategy})"
      _ -> "-"
    end
  end

  defp status_color(:failed), do: "danger"
  defp status_color(:processed), do: "success"
  defp status_color(:processing), do: "warning"
  defp status_color(_), do: "neutral"

  defp signature_state(delivery) do
    cond do
      delivery.signature_valid == true -> "valid"
      is_binary(delivery.signature_error) -> "invalid (#{delivery.signature_error})"
      true -> "unknown"
    end
  end

  defp delivery_session_id(delivery) do
    runtime_result = delivery.runtime_result || %{}
    runtime_result["session_id"] || runtime_result[:session_id]
  end

  defp delivery_case_id(delivery) do
    runtime_result = delivery.runtime_result || %{}
    runtime_result["case_id"] || runtime_result[:case_id]
  end

  defp replayable?(delivery), do: delivery.status not in [:received, :processing]

  defp pretty_json(nil), do: "{}"

  defp pretty_json(value) do
    case Jason.encode(value, pretty: true) do
      {:ok, encoded} -> encoded
      _ -> inspect(value, pretty: true, limit: :infinity)
    end
  end

  defp nav_class(true), do: "px-3 py-1.5 rounded-base bg-accent text-foreground font-medium"
  defp nav_class(false), do: "px-3 py-1.5 rounded-base text-foreground-soft hover:bg-accent"
end
