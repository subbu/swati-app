defmodule SwatiWeb.CustomersLive.Helpers do
  @moduledoc false
  use Phoenix.Component

  alias SwatiWeb.Formatting

  def status_badge(status) do
    case to_string(status || "") do
      "active" -> %{label: "Active", color: "success"}
      "inactive" -> %{label: "Inactive", color: "neutral"}
      "blocked" -> %{label: "Blocked", color: "danger"}
      _ -> %{label: "Unknown", color: "info"}
    end
  end

  def status_options do
    [
      {"All statuses", ""},
      {"Active", "active"},
      {"Inactive", "inactive"},
      {"Blocked", "blocked"}
    ]
  end

  def status_filter_label(filters) do
    case Map.get(filters, "status") do
      nil -> "Status"
      "" -> "Status"
      status -> status_badge(status).label
    end
  end

  def customer_name(customer) do
    customer.name || customer.primary_email || customer.primary_phone || "Customer"
  end

  def customer_contact(customer) do
    customer.primary_email || customer.primary_phone || "—"
  end

  def identity_address(identity) do
    identity.address || identity.external_id || "—"
  end

  def identity_channel_name(identity) do
    case identity.channel do
      nil -> "—"
      channel -> channel.key || channel.name || to_string(channel.type || "")
    end
  end

  def identity_channel_list(identities) do
    identities
    |> Enum.map(&identity_channel_name/1)
    |> Enum.reject(&(&1 == "—"))
    |> Enum.uniq()
  end

  def identity_channels_label(channels) do
    case channels do
      [] -> "—"
      _channels -> Enum.join(channels, " · ")
    end
  end

  def identity_group_key(identity) do
    address = identity_address(identity)

    if address == "—" do
      {:identity, identity.id}
    else
      {:address, address}
    end
  end

  def identity_groups(identities) do
    identities
    |> Enum.with_index()
    |> Enum.group_by(fn {identity, _idx} -> identity_group_key(identity) end)
    |> Enum.map(fn {_key, entries} ->
      {identity, idx} = Enum.min_by(entries, fn {_identity, idx} -> idx end)
      identity_list = Enum.map(entries, &elem(&1, 0))

      %{
        address: identity_address(identity),
        icon: identity_icon(identity),
        channels: identity_channel_list(identity_list),
        sort_index: idx
      }
    end)
    |> Enum.sort_by(& &1.sort_index)
  end

  def identity_icon(identity) do
    case to_string(identity.kind || "") do
      "phone" -> "hero-phone"
      "email" -> "hero-envelope"
      "handle" -> "hero-at-symbol"
      "external" -> "hero-hashtag"
      _ -> "hero-user"
    end
  end

  def format_datetime(nil, _tenant), do: "—"

  def format_datetime(%DateTime{} = dt, tenant) do
    Formatting.datetime(dt, tenant)
  end

  def format_relative(nil, _tenant), do: "—"

  def format_relative(%DateTime{} = dt, _tenant) do
    seconds = max(DateTime.diff(DateTime.utc_now(), dt, :second), 0)

    cond do
      seconds < 60 ->
        "just now"

      seconds < 3600 ->
        minutes = div(seconds, 60)
        "#{minutes} min#{plural_suffix(minutes)} ago"

      seconds < 86_400 ->
        hours = div(seconds, 3600)
        "#{hours} hour#{plural_suffix(hours)} ago"

      seconds < 2_592_000 ->
        days = div(seconds, 86_400)
        "#{days} day#{plural_suffix(days)} ago"

      seconds < 31_536_000 ->
        months = div(seconds, 2_592_000)
        "#{months} month#{plural_suffix(months)} ago"

      true ->
        years = div(seconds, 31_536_000)
        "#{years} year#{plural_suffix(years)} ago"
    end
  end

  def sort_button_class(column, %{column: column}),
    do:
      "-mx-2 cursor-pointer flex items-center gap-0.5 px-2 py-1 rounded-base hover:bg-accent text-foreground"

  def sort_button_class(_column, _sort),
    do:
      "-mx-2 cursor-pointer flex items-center gap-0.5 px-2 py-1 rounded-base hover:bg-accent text-foreground-soft"

  def sort_icon_class(column, %{column: column}), do: "text-foreground"
  def sort_icon_class(_column, _sort), do: "text-foreground-softest"

  attr :column, :string, required: true
  attr :sort, :map, required: true

  def sort_icon(assigns) do
    ~H"""
    <%= if @sort.column == @column do %>
      <svg
        xmlns="http://www.w3.org/2000/svg"
        viewBox="0 0 16 16"
        class={["size-4", sort_icon_class(@column, @sort)]}
      >
        <path
          fill="currentColor"
          d={if @sort.direction == "asc", do: "M11 7H5l3-4z", else: "M5 9h6l-3 4z"}
        />
      </svg>
    <% else %>
      <svg
        xmlns="http://www.w3.org/2000/svg"
        viewBox="0 0 16 16"
        class={["size-4", sort_icon_class(@column, @sort)]}
      >
        <path fill="currentColor" d="M11 7H5l3-4z" />
        <path fill="currentColor" d="M5 9h6l-3 4z" />
      </svg>
    <% end %>
    """
  end

  def next_sort(%{column: column, direction: direction}, column),
    do: %{column: column, direction: toggle_sort_direction(direction)}

  def next_sort(_sort, column),
    do: %{column: column, direction: default_sort_direction(column)}

  def toggle_sort_direction("asc"), do: "desc"
  def toggle_sort_direction(_direction), do: "asc"

  def default_sort_direction("updated_at"), do: "desc"
  def default_sort_direction(_column), do: "asc"

  defp plural_suffix(value) when value == 1, do: ""
  defp plural_suffix(_value), do: "s"
end
