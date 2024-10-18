defmodule NervesHubCLI.CLI.Shell do
  alias NervesHubCLI.CLI.Utils
  alias Owl.IO, as: OIO
  alias Owl.Data

  @spec info(IO.ANSI.ansidata()) :: :ok
  def info(message) do
    message
    |> OIO.puts()
  end

  @spec error(IO.ANSI.ansidata()) :: :ok
  def error(message) do
    message
    |> Data.tag(:red)
    |> OIO.puts(:stderr)
  end

  @spec raise(String.t()) :: no_return()
  def raise(output) do
    error(output)
    System.halt(1)
  end

  @spec prompt(String.t()) :: String.t()
  def prompt(message) do
    OIO.input(label: message, cast: :string)
  end

  @spec yes?(String.t()) :: boolean()
  def yes?(message) do
    System.get_env("NERVES_HUB_NON_INTERACTIVE") ||
      OIO.confirm(message: message, answers: [
        true: {"y", ["Y", "yes", "YES", "Yes"]},
        false: {"n", ["N", "no", "NO", "No"]},
      ])
  end

  @spec request_auth() :: NervesHubCLI.API.Auth.t() | nil
  def request_auth() do
    if token = Utils.token() do
      %NervesHubCLI.API.Auth{token: token}
    else
      __MODULE__.raise("You are not authenticated")
    end
  end

  def request_password(_prompt, 0) do
    {:error, :failed_password}
  end

  def request_keys(org, name) do
    request_keys(org, name, "Local signing key password for '#{name}': ")
  end

  def request_keys(org, name, prompt) do
    env_pub_key = System.get_env("NERVES_HUB_FW_PUBLIC_KEY")
    env_priv_key = System.get_env("NERVES_HUB_FW_PRIVATE_KEY")

    if env_pub_key != nil and env_priv_key != nil do
      {:ok, env_pub_key, env_priv_key}
    else
      key_password = password_get(prompt)
      NervesHubCLI.Key.get(org, name, key_password)
    end
  end

  # Password prompt that hides input by every 1ms
  # clearing the line with stderr
  @spec password_get(String.t()) :: String.t()
  def password_get(prompt) do
    OIO.input(label: prompt, secret: true, cast: :string)
  end

  @dialyzer [{:no_return, render_error: 1}, {:no_fail_call, render_error: 1}]

  @spec render_error([{:error, any()}] | {:error, any()}, boolean() | nil) ::
          :ok | no_return()
  def render_error(errors, halt? \\ true) do
    _ = do_render_error(errors)

    if halt? do
      System.halt(1)
    else
      :ok
    end
  end

  @spec do_render_error(any()) :: :ok
  def do_render_error(errors) when is_list(errors) do
    Enum.each(errors, &do_render_error/1)
  end

  def do_render_error({error, reasons}) when is_list(reasons) do
    error("#{error}")
    for reason <- reasons, do: error("  #{reason}")
    :ok
  end

  def do_render_error({:error, reason}) when is_binary(reason) do
    error(reason)
  end

  def do_render_error({:error, %{"status" => "forbidden"}}) do
    error("Invalid credentials")
    error("Your user token has either expired or has been revoked.")
    error("Please authenticate again:")
    error("  mix nerves_hub.user auth")
  end

  def do_render_error({:error, %{"status" => reason}}) do
    error(reason)
  end

  def do_render_error({:error, %{"errors" => reason}}) when is_binary(reason) do
    error(reason)
  end

  def do_render_error({:error, %{"errors" => reasons}}) when is_list(reasons) do
    error("HTTP error")
    for {key, reason} <- reasons, do: error("  #{key}: #{reason}")
    :ok
  end

  def do_render_error(error) do
    error("Unhandled error: #{inspect(error)}")
  end

  def start_progress_bar(label, total_size, identifier \\ :progress, style \\ :slim) do
    params = [id: identifier, label: label, total: total_size, timer: true]
    Owl.ProgressBar.start(params ++ progress_style(style))
  end

  def start_file_progress_bar(label, total_size, identifier \\ :progress, style \\ :slim) do
    # Would love to use file_size and the unit to show a nice b/kb/mb type indication but Owl
    # actually makes that a bit tricky, not bothering for now
    params = [id: identifier, label: label, total: total_size, absolute_values: true, timer: true]
    Owl.ProgressBar.start(params ++ progress_style(style))
  end

  # Box drawing unicode: https://symbl.cc/en/unicode/blocks/box-drawing/
  defp progress_style(:bold) do
    [
      start_symbol: "",
      partial_symbols: [Data.tag("╾", :cyan), Data.tag("─", :cyan)],
      filled_symbol: Data.tag("━", :cyan),
      end_symbol: ""
    ]
  end

  defp progress_style(:slim) do
    [
      start_symbol: "",
      partial_symbols: [],
      filled_symbol: Data.tag("─", :cyan),
      end_symbol: ""
    ]
  end

  def progress(increment \\ 1, identifier \\ :progress) do
    Owl.ProgressBar.inc(id: identifier, step: increment)
  end
end
