defmodule Flippant.Adapters.Memory do
  use GenServer

  def start_link do
    GenServer.start_link(__MODULE__, :ok, [name: __MODULE__])
  end

  def add(feature) when is_binary(feature) do
    GenServer.cast(adapter, {:add, feature})
  end

  def clear do
    GenServer.cast(adapter, :clear)
  end

  def disable(feature, group)
      when is_binary(feature)
      when is_binary(group) do

    GenServer.cast(adapter, {:remove, feature, group})
  end

  def enable(feature, group, values \\ true)
      when is_binary(feature)
      when is_binary(group) do

    GenServer.cast(adapter, {:add, feature, {group, values}})
  end

  def features(group \\ :all) do
    GenServer.call(adapter, {:features, group})
  end

  def remove(feature) when is_binary(feature) do
    GenServer.cast(adapter, {:remove, feature})
  end

  # Callbacks

  def init(:ok) do
    table = :ets.new(:features, [])

    {:ok, table}
  end

  def handle_cast({:add, feature}, table) do
    case :ets.lookup(table, feature) do
      [] -> :ets.insert(table, {feature, []})
       _ -> true
    end

    {:noreply, table}
  end
  def handle_cast({:add, feature, rule}, table) do
    case :ets.lookup(table, feature) do
      [{_, rules}] -> :ets.insert(table, {feature, [rule | rules]})
      [] -> :ets.insert(table, {feature, [rule]})
    end

    {:noreply, table}
  end
  def handle_cast(:clear, table) do
    :ets.delete_all_objects(table)

    {:noreply, table}
  end
  def handle_cast({:remove, feature}, table) do
    :ets.delete(table, feature)

    {:noreply, table}
  end
  def handle_cast({:remove, feature, group}, table) do
    case :ets.lookup(table, feature) do
      [{_, rules}] -> :ets.insert(table, {feature, without_group(rules, group)})
                   _ -> true
    end

    {:noreply, table}
  end

  def handle_call({:features, group}, _from, table) do
    {:reply, get_features(table, group), table}
  end

  # Helpers

  defp adapter do
    Process.whereis(__MODULE__)
  end

  defp get_features(table, :all) do
    table
    |> :ets.tab2list
    |> Enum.map(&(elem &1, 0))
  end
  defp get_features(table, for_group) do
    table
    |> :ets.tab2list
    |> Enum.filter(fn({_, rules}) ->
         Enum.any?(rules, fn({group, _}) -> group == for_group end)
       end)
    |> Enum.map(&(elem &1, 0))
  end

  defp without_group(rules, to_remove) do
    Enum.reject(rules, fn({group, _}) -> group == to_remove end)
  end
end
