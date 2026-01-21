defmodule Swati.Channels.Imap.ClientExImap do
  @behaviour Swati.Channels.Imap.Client

  @impl true
  def start_connection_ssl(host, port), do: ExImapClient.start_connection_ssl(host, port)

  @impl true
  def start_connection(host, port), do: ExImapClient.start_connection(host, port)

  @impl true
  def login(identifier, username, password),
    do: ExImapClient.login(identifier, username, password)

  @impl true
  def select(identifier, mailbox), do: ExImapClient.select(identifier, mailbox)

  @impl true
  def uid_search(identifier, criteria), do: ExImapClient.uid_search(identifier, criteria)

  @impl true
  def uid_fetch(identifier, from_uid, to_uid, macro, timeout) do
    ExImapClient.uid_fetch(identifier, from_uid, to_uid, macro, timeout)
  end

  @impl true
  def logout(identifier), do: ExImapClient.logout(identifier)
end
