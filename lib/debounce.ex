defmodule Debounce do
  @behaviour :gen_statem

  def start_link(apply, timeout, opts \\ []) do
    do_start(:start_link, apply, timeout, opts)
  end

  def start(apply, timeout, opts \\ []) do
    do_start(:start, apply, timeout, opts)
  end

  def stop(debounce, reason \\ :normal, timeout \\ :infinity) do
    :gen_statem.stop(debounce, reason, timeout)
  end

  def apply(debounce) do
    :gen_statem.call(debounce, :apply)
  end

  def cancel(debounce) do
    :gen_statem.call(debounce, :cancel)
  end

  def change_function(debounce, new_function) do
    :gen_statem.call(debounce, {:change_function, mfa(new_function)})
  end

  def change_timeout(debounce, new_timeout) when is_integer(new_timeout) do
    :gen_statem.call(debounce, {:change_timeout, new_timeout})
  end

  ## Callbacks

  import Record

  defrecord :data, [:mfa, :timeout]

  @doc false
  def callback_mode, do: :state_functions

  @doc false
  def init({mfa, timeout}) do
    {:ok, :waiting, data(mfa: mfa, timeout: timeout)}
  end

  @doc false
  def waiting({:call, from}, :apply, data(mfa: mfa, timeout: timeout) = data) do
    {:next_state, :counting, data,
     [{:reply, from, :ok}, {:state_timeout, timeout, mfa}]}
  end

  def waiting({:call, from}, :cancel, data) do
    {:keep_state, data, {:reply, from, :ok}}
  end

  def waiting(event, event_content, data) do
    handle_event(event, event_content, data)
  end

  @doc false
  def counting({:call, from}, :apply, data(mfa: mfa, timeout: timeout) = data) do
    {:keep_state, data,
     [{:reply, from, :ok}, {:state_timeout, timeout, mfa}]}
  end

  def counting({:call, from}, :cancel, data) do
    {:next_state, :wating, data, {:reply, from, :ok}}
  end

  def counting(:state_timeout, {m, f, a}, data) do
    apply(m, f, a)
    {:next_state, :waiting, data}
  end

  def counting(event, event_content, data) do
    handle_event(event, event_content, data)
  end

  @doc false
  def handle_event({:call, from}, {:change_function, mfa}, data) do
    {:keep_state, data(data, mfa: mfa), {:reply, from, :ok}}
  end

  def handle_event({:call, from}, {:change_timeout, timeout}, data) do
    {:keep_state, data(data, timeout: timeout), {:reply, from, :ok}}
  end

  def handle_event({:call, _from}, msg, data) do
    {:stop, {:bad_call, msg}, data}
  end

  def handle_event(:cast, msg, data) do
    {:stop, {:bad_cast, msg}, data}
  end

  def handle_event(:info, msg, data) do
    proc =
      case Process.info(self(), :registered_name) do
        {_, []}   -> self()
        {_, name} -> name
      end

    :error_logger.error_msg('~p ~p received unexpected message: ~p~n',
      [__MODULE__, proc, msg])
    {:keep_state, data}
  end

  @doc false
  def terminate(_reason, _state, _data) do
    :ok
  end

  @doc false
  def code_change(_vsn, state, data, _extra) do
    {:ok, state, data}
  end

  ## Helpers

  defp do_start(start, apply, timeout, opts) when is_integer(timeout) do
    mfa = mfa(apply)
    if name = name(opts[:name]) do
      apply(:gen_statem, start, [name, __MODULE__, {mfa, timeout}, opts])
    else
      apply(:gen_statem, start, [__MODULE__, {mfa, timeout}, opts])
    end
  end

  defp name(nil), do: nil
  defp name(atom) when is_atom(atom), do: atom
  defp name(other), do: other

  defmacrop is_mfa(tuple) do
    quote do
      is_atom(elem(unquote(tuple), 0)) and
      is_atom(elem(unquote(tuple), 1)) and
      is_list(elem(unquote(tuple), 2))
    end
  end

  defp mfa(fun) when is_function(fun), do: {:erlang, :apply, [fun]}
  defp mfa(mfa) when is_mfa(mfa), do: mfa
end
