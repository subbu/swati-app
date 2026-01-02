defmodule SwatiWeb.CallsLive.Show do
  use SwatiWeb, :live_view

  alias Swati.Calls

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="space-y-8">
        <div class="flex items-center justify-between">
          <div>
            <h1 class="text-2xl font-semibold">Call detail</h1>
            <p class="text-sm text-base-content/70">
              {assigns.call.from_number} → {assigns.call.to_number}
            </p>
          </div>
          <.button navigate={~p"/dashboard/calls"} variant="ghost">Back</.button>
        </div>

        <section class="rounded-2xl border border-base-300 bg-base-100 p-6 space-y-4">
          <h2 class="text-lg font-semibold">Summary</h2>
          <p class="text-sm text-base-content/70">Status: {assigns.call.status}</p>
          <p class="text-sm text-base-content/70">Duration: {assigns.call.duration_seconds || 0}s</p>
          <p class="text-base">{assigns.call.summary || "—"}</p>
        </section>

        <section class="rounded-2xl border border-base-300 bg-base-100 p-6 space-y-4">
          <h2 class="text-lg font-semibold">Recording</h2>
          <%= if recording_links(@call) == [] do %>
            <p class="text-sm text-base-content/70">No recordings available.</p>
          <% else %>
            <.table>
              <.table_head>
                <:col>Track</:col>
                <:col>Preview</:col>
                <:col class="text-right">Link</:col>
              </.table_head>
              <.table_body>
                <.table_row :for={{label, url} <- recording_links(@call)}>
                  <:cell>{label}</:cell>
                  <:cell>
                    <audio controls src={url} class="w-full max-w-xs" preload="none"></audio>
                  </:cell>
                  <:cell class="text-right">
                    <.link
                      href={url}
                      target="_blank"
                      rel="noopener noreferrer"
                      class="text-sm underline"
                    >
                      Open
                    </.link>
                  </:cell>
                </.table_row>
              </.table_body>
            </.table>
          <% end %>
        </section>

        <section class="rounded-2xl border border-base-300 bg-base-100 p-6 space-y-4">
          <h2 class="text-lg font-semibold">Artifacts</h2>
          <%= if artifact_links(@call) == [] do %>
            <p class="text-sm text-base-content/70">No artifacts available.</p>
          <% else %>
            <.table>
              <.table_head>
                <:col>Artifact</:col>
                <:col class="text-right">Link</:col>
              </.table_head>
              <.table_body>
                <.table_row :for={{label, url} <- artifact_links(@call)}>
                  <:cell>{label}</:cell>
                  <:cell class="text-right">
                    <.link
                      href={url}
                      target="_blank"
                      rel="noopener noreferrer"
                      class="text-sm underline"
                    >
                      Open
                    </.link>
                  </:cell>
                </.table_row>
              </.table_body>
            </.table>
          <% end %>
        </section>

        <section class="rounded-2xl border border-base-300 bg-base-100 p-6 space-y-4">
          <h2 class="text-lg font-semibold">Transcript</h2>
          <pre phx-no-curly-interpolation class="text-xs whitespace-pre-wrap text-base-content/70">
            {inspect(assigns.call.transcript || %{}, pretty: true)}
          </pre>
        </section>

        <section class="rounded-2xl border border-base-300 bg-base-100 p-6 space-y-4">
          <h2 class="text-lg font-semibold">Events</h2>
          <.table>
            <.table_head>
              <:col>Time</:col>
              <:col>Type</:col>
              <:col>Payload</:col>
            </.table_head>
            <.table_body>
              <.table_row :for={event <- @events}>
                <:cell>{format_datetime(event.ts)}</:cell>
                <:cell>{event.type}</:cell>
                <:cell class="text-xs text-base-content/70">
                  {inspect(event.payload || %{}, pretty: true)}
                </:cell>
              </.table_row>
            </.table_body>
          </.table>
        </section>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    call = Calls.get_call!(socket.assigns.current_scope.tenant.id, id)

    {:ok, assign(socket, call: call, events: call.events)}
  end

  defp format_datetime(nil), do: "—"

  defp format_datetime(%DateTime{} = dt) do
    Calendar.strftime(dt, "%b %-d, %Y %H:%M:%S")
  end

  defp recording_links(call) do
    recording = call.recording || %{}

    [
      {"Stereo mix", map_value(recording, "stereo_url", :stereo_url)},
      {"Caller track", map_value(recording, "caller_url", :caller_url)},
      {"Agent track", map_value(recording, "agent_url", :agent_url)}
    ]
    |> Enum.filter(&present_url?/1)
  end

  defp artifact_links(call) do
    transcript = call.transcript || %{}

    [
      {"Transcript text", map_value(transcript, "text_url", :text_url)},
      {"Transcript jsonl", map_value(transcript, "jsonl_url", :jsonl_url)}
    ]
    |> Enum.filter(&present_url?/1)
  end

  defp map_value(map, string_key, atom_key) when is_map(map) do
    Map.get(map, string_key) || Map.get(map, atom_key)
  end

  defp present_url?({_label, url}), do: url not in [nil, ""]
end
