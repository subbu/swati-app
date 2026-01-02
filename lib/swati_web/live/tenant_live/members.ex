defmodule SwatiWeb.TenantLive.Members do
  use SwatiWeb, :live_view

  alias Swati.Accounts

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="space-y-10">
        <div class="space-y-1">
          <h1 class="text-2xl font-semibold">Members</h1>
          <p class="text-sm text-base-content/70">
            Manage access for {@current_scope.tenant.name}.
          </p>
        </div>

        <section class="rounded-2xl border border-base-300 bg-base-100 p-6 space-y-4">
          <div>
            <h2 class="text-lg font-semibold">Invite a teammate</h2>
            <p class="text-sm text-base-content/70">
              Send a magic link to add someone to this workspace.
            </p>
          </div>

          <.form for={@form} id="invite-member-form" phx-submit="invite">
            <div class="grid gap-4 sm:grid-cols-[1.5fr_1fr_auto] items-end">
              <.input
                field={@form[:email]}
                type="email"
                label="Email"
                autocomplete="email"
                required
              />

              <.select
                field={@form[:role]}
                label="Role"
                options={@role_options}
                native
              />

              <.button class="btn btn-primary w-full sm:w-auto" phx-disable-with="Sending invite...">
                Send invite
              </.button>
            </div>
          </.form>
        </section>

        <section class="rounded-2xl border border-base-300 bg-base-100 p-6 space-y-4">
          <div>
            <h2 class="text-lg font-semibold">Current members</h2>
            <p class="text-sm text-base-content/70">
              Roles control who can manage members.
            </p>
          </div>

          <.table>
            <.table_head>
              <:col>Email</:col>
              <:col>Role</:col>
              <:col>Joined</:col>
            </.table_head>
            <.table_body id="members" phx-update="stream">
              <.table_row id="members-empty" class="hidden only:table-row">
                <:cell colspan="3" class="text-sm text-base-content/70 text-center py-6">
                  No members yet.
                </:cell>
              </.table_row>

              <.table_row :for={{id, membership} <- @streams.members} id={id}>
                <:cell class="font-medium">{membership.user.email}</:cell>
                <:cell>
                  <.badge color={role_color(membership.role)} variant="soft">
                    {format_role(membership.role)}
                  </.badge>
                </:cell>
                <:cell class="text-sm text-base-content/70">
                  {format_date(membership.inserted_at)}
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
  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(:page_title, "Members")
      |> assign(:role_options, role_options())

    if Accounts.authorized?(socket.assigns.current_scope, :manage_members) do
      {:ok, load_members(socket)}
    else
      {:ok, unauthorized(socket)}
    end
  end

  @impl true
  def handle_event("invite", %{"membership_invite" => params}, socket) do
    case Accounts.invite_member(
           socket.assigns.current_scope,
           params,
           &url(~p"/users/log-in/#{&1}")
         ) do
      {:ok, _membership} ->
        {:noreply,
         socket
         |> put_flash(:info, "Invite sent.")
         |> refresh_members()}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign_form(socket, changeset)}

      {:error, :unauthorized} ->
        {:noreply, unauthorized(socket)}
    end
  end

  defp load_members(socket) do
    case Accounts.list_members(socket.assigns.current_scope) do
      {:ok, members} ->
        socket
        |> assign_form(Accounts.change_membership_invite())
        |> stream(:members, members, reset: true)

      {:error, _reason} ->
        unauthorized(socket)
    end
  end

  defp refresh_members(socket) do
    case Accounts.list_members(socket.assigns.current_scope) do
      {:ok, members} ->
        socket
        |> assign_form(Accounts.change_membership_invite())
        |> stream(:members, members, reset: true)

      {:error, _reason} ->
        unauthorized(socket)
    end
  end

  defp assign_form(socket, %Ecto.Changeset{} = changeset) do
    form = to_form(changeset, as: :membership_invite)
    assign(socket, form: form)
  end

  defp role_options do
    [
      {"Owner", :owner},
      {"Admin", :admin},
      {"Agent", :agent},
      {"Member", :member},
      {"Viewer", :viewer}
    ]
  end

  defp format_role(role), do: role |> Atom.to_string() |> String.capitalize()

  defp role_color(:owner), do: "primary"
  defp role_color(:admin), do: "info"
  defp role_color(:agent), do: "accent"
  defp role_color(:member), do: "success"
  defp role_color(:viewer), do: "neutral"
  defp role_color(_), do: "primary"

  defp format_date(nil), do: "—"
  defp format_date(%DateTime{} = dt), do: Calendar.strftime(dt, "%b %-d, %Y")

  defp unauthorized(socket) do
    socket
    |> put_flash(:error, "You do not have access to manage members.")
    |> redirect(to: ~p"/")
  end
end
