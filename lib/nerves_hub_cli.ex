defmodule NervesHubCLI do
  use Application

  @moduledoc """
  TBD
  """

  @typedoc """
  Firmware update public keys can be referred to by their contents.
  """
  @type fwup_public_key_ref :: String.t()

  def start(a, b) do
    IO.puts("started...")
    IO.inspect(a, label: "a")
    IO.inspect(b, label: "b")
    args = Burrito.Util.Args.argv()
    IO.inspect(args, label: "args")
    System.halt(0)
  end

  @spec default_description() :: String.t()
  def default_description() do
    {:ok, hostname} = :inet.gethostname()
    to_string(hostname)
  end

  @spec home_dir() :: String.t()
  def home_dir() do
    override_dir =
      Application.get_env(:nerves_hub_cli, :home_dir) || System.get_env("NERVES_HUB_HOME")

    if override_dir == nil or override_dir == "" do
      Path.expand("~/.nerves-hub")
    else
      override_dir
    end
  end
end
