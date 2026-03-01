defmodule SwatiWeb.InboundEmailLive.Index do
  use SwatiWeb, :live_view

  alias Swati.Agents
  alias Swati.Channels
  alias Swati.Inbound
  alias SwatiWeb.InboundEmailLive.Components

  @impl true
  def mount(_params, _session, socket) do
    if Swati.Accounts.authorized?(socket.assigns.current_scope, :manage_channels) do
      tenant_id = socket.assigns.current_scope.tenant.id

      socket =
        socket
        |> assign(:tenant_id, tenant_id)
        |> assign(:agents, Agents.list_agents(tenant_id))
        |> assign(:connector_form, connector_form_defaults())
        |> assign(:binding_form, binding_form_defaults())
        |> assign(:rule_form, rule_form_defaults())
        |> assign(:route_preview_form, route_preview_form_defaults())
        |> assign(:route_preview_result, nil)
        |> assign(:inbound_enabled, Inbound.enabled?())
        |> load_data()

      {:ok, socket}
    else
      {:ok,
       socket
       |> put_flash(:error, "You don't have permission to access this page.")
       |> redirect(to: ~p"/dashboard")}
    end
  end

  @impl true
  def handle_event("refresh", _params, socket) do
    {:noreply, load_data(socket)}
  end

  @impl true
  def handle_event("create_connector", %{"connector" => params}, socket) do
    attrs = %{
      name: Map.get(params, "name"),
      provider: "resend",
      default_endpoint_address: blank_to_nil(Map.get(params, "default_endpoint_address")),
      default_agent_id: blank_to_nil(Map.get(params, "default_agent_id")),
      signing_secret: blank_to_nil(Map.get(params, "signing_secret")),
      metadata: %{"created_from" => "inbound_email_live"}
    }

    case Inbound.create_connector(socket.assigns.tenant_id, attrs) do
      {:ok, _connector} ->
        {:noreply,
         socket
         |> put_flash(:info, "Inbound connector created.")
         |> assign(:connector_form, connector_form_defaults())
         |> load_data()}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply,
         socket
         |> put_flash(:error, format_changeset_errors(changeset))
         |> assign(:connector_form, Map.merge(connector_form_defaults(), params))}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, "Failed to create connector: #{inspect(reason)}")}
    end
  end

  @impl true
  def handle_event("delete_connector", %{"id" => id}, socket) do
    connector = Inbound.get_connector!(socket.assigns.tenant_id, id)

    case Inbound.delete_connector(connector) do
      {:ok, _connector} ->
        {:noreply,
         socket
         |> put_flash(:info, "Connector deleted.")
         |> load_data()}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Unable to delete connector.")}
    end
  end

  @impl true
  def handle_event(
        "update_connector_secret",
        %{"connector_id" => id, "signing_secret" => secret},
        socket
      ) do
    connector = Inbound.get_connector!(socket.assigns.tenant_id, id)

    case Inbound.update_connector(connector, %{signing_secret: blank_to_nil(secret)}) do
      {:ok, _connector} ->
        {:noreply,
         socket
         |> put_flash(:info, "Signing secret updated.")
         |> load_data()}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, put_flash(socket, :error, format_changeset_errors(changeset))}

      {:error, reason} ->
        {:noreply,
         put_flash(socket, :error, "Failed to update signing secret: #{inspect(reason)}")}
    end
  end

  @impl true
  def handle_event("create_rule", %{"rule" => params}, socket) do
    attrs = %{
      "name" => Map.get(params, "name"),
      "agent_id" => Map.get(params, "agent_id"),
      "priority" => parse_integer(Map.get(params, "priority"), 100),
      "action" => Map.get(params, "action", "owner"),
      "predicates" => build_predicates(params)
    }

    case Inbound.create_rule(socket.assigns.tenant_id, attrs) do
      {:ok, _rule} ->
        {:noreply,
         socket
         |> put_flash(:info, "Inbound rule added.")
         |> assign(:rule_form, rule_form_defaults())
         |> load_data()}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply,
         socket
         |> put_flash(:error, format_changeset_errors(changeset))
         |> assign(:rule_form, Map.merge(rule_form_defaults(), params))}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, "Failed to create rule: #{inspect(reason)}")}
    end
  end

  @impl true
  def handle_event("delete_rule", %{"id" => id}, socket) do
    rule = Inbound.get_rule!(socket.assigns.tenant_id, id)

    case Inbound.delete_rule(rule) do
      {:ok, _rule} ->
        {:noreply,
         socket
         |> put_flash(:info, "Rule deleted.")
         |> load_data()}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Unable to delete rule.")}
    end
  end

  @impl true
  def handle_event("create_binding", %{"binding" => params}, socket) do
    address = blank_to_nil(Map.get(params, "address"))
    owner_agent_id = blank_to_nil(Map.get(params, "owner_agent_id"))

    if is_nil(address) do
      {:noreply, put_flash(socket, :error, "Binding address is required.")}
    else
      case Inbound.upsert_address_binding(socket.assigns.tenant_id, address, owner_agent_id) do
        {:ok, _endpoint} ->
          {:noreply,
           socket
           |> put_flash(:info, "Address binding saved.")
           |> assign(:binding_form, binding_form_defaults())
           |> load_data()}

        {:error, %Ecto.Changeset{} = changeset} ->
          {:noreply,
           socket
           |> put_flash(:error, format_changeset_errors(changeset))
           |> assign(:binding_form, Map.merge(binding_form_defaults(), params))}

        {:error, reason} ->
          {:noreply, put_flash(socket, :error, "Failed to save binding: #{inspect(reason)}")}
      end
    end
  end

  @impl true
  def handle_event("clear_binding", %{"endpoint_id" => endpoint_id}, socket) do
    endpoint = Channels.get_endpoint!(socket.assigns.tenant_id, endpoint_id)

    case Inbound.clear_address_binding(endpoint) do
      {:ok, _endpoint} ->
        {:noreply,
         socket
         |> put_flash(:info, "Address binding cleared.")
         |> load_data()}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, put_flash(socket, :error, format_changeset_errors(changeset))}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, "Failed to clear binding: #{inspect(reason)}")}
    end
  end

  @impl true
  def handle_event("preview_route", %{"route_preview" => params}, socket) do
    connector_id = Map.get(params, "connector_id")

    if is_nil(blank_to_nil(connector_id)) do
      {:noreply, put_flash(socket, :error, "Select a connector for route preview.")}
    else
      connector = Inbound.get_connector!(socket.assigns.tenant_id, connector_id)

      case Inbound.preview_route(connector, params) do
        {:ok, result} ->
          {:noreply,
           socket
           |> assign(:route_preview_form, Map.merge(route_preview_form_defaults(), params))
           |> assign(:route_preview_result, result)}

        {:error, reason} ->
          {:noreply,
           socket
           |> put_flash(:error, "Route preview failed: #{inspect(reason)}")
           |> assign(:route_preview_result, nil)}
      end
    end
  end

  @impl true
  def handle_event("replay_delivery", %{"id" => id}, socket) do
    delivery = Inbound.get_delivery!(socket.assigns.tenant_id, id)

    case Inbound.replay_delivery(delivery) do
      {:ok, _delivery} ->
        {:noreply,
         socket
         |> put_flash(:info, "Delivery replay queued.")
         |> load_data()}

      {:error, :delivery_busy} ->
        {:noreply, put_flash(socket, :error, "Delivery is already being processed.")}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, "Failed to replay delivery: #{inspect(reason)}")}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Components.page socket_assigns={assigns} />
    """
  end

  defp load_data(socket) do
    tenant_id = socket.assigns.tenant_id

    socket
    |> assign(:connectors, Inbound.list_connectors(tenant_id))
    |> assign(:bindings, Inbound.list_address_bindings(tenant_id))
    |> assign(:rules, Inbound.list_rules(tenant_id))
    |> assign(:deliveries, Inbound.list_deliveries(tenant_id, limit: 50))
    |> assign(:email_sessions, Inbound.list_email_sessions(tenant_id, limit: 50))
  end

  defp connector_form_defaults do
    %{
      "name" => "",
      "default_endpoint_address" => "",
      "default_agent_id" => "",
      "signing_secret" => ""
    }
  end

  defp rule_form_defaults do
    %{
      "name" => "",
      "agent_id" => "",
      "priority" => "100",
      "action" => "owner",
      "to_addresses" => "",
      "to_domains" => "",
      "subject_contains" => ""
    }
  end

  defp binding_form_defaults do
    %{
      "address" => "",
      "owner_agent_id" => ""
    }
  end

  defp route_preview_form_defaults do
    %{
      "connector_id" => "",
      "from" => "",
      "to" => "",
      "subject" => "",
      "message_id" => "",
      "in_reply_to" => "",
      "references" => ""
    }
  end

  defp build_predicates(params) do
    predicates = %{}

    predicates =
      put_if_present(predicates, "to_addresses", split_csv(Map.get(params, "to_addresses")))

    predicates =
      put_if_present(predicates, "to_domains", split_csv(Map.get(params, "to_domains")))

    put_if_present(predicates, "subject_contains", Map.get(params, "subject_contains"))
  end

  defp split_csv(nil), do: []

  defp split_csv(value) when is_binary(value) do
    value
    |> String.split([",", ";"], trim: true)
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
  end

  defp split_csv(_value), do: []

  defp put_if_present(map, _key, nil), do: map
  defp put_if_present(map, _key, ""), do: map
  defp put_if_present(map, _key, []), do: map
  defp put_if_present(map, key, value), do: Map.put(map, key, value)

  defp blank_to_nil(nil), do: nil

  defp blank_to_nil(value) when is_binary(value) do
    case String.trim(value) do
      "" -> nil
      trimmed -> trimmed
    end
  end

  defp blank_to_nil(value), do: value

  defp parse_integer(nil, default), do: default

  defp parse_integer(value, default) do
    case Integer.parse(to_string(value)) do
      {number, ""} -> number
      _ -> default
    end
  end

  defp format_changeset_errors(changeset) do
    changeset
    |> Ecto.Changeset.traverse_errors(fn {msg, opts} ->
      Enum.reduce(opts, msg, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
    |> Enum.flat_map(fn {field, messages} ->
      Enum.map(messages, fn message -> "#{field} #{message}" end)
    end)
    |> Enum.join(", ")
  end
end
