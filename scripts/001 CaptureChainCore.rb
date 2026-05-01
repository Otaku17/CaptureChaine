module CaptureChain
  module_function

  def config
    Configs.capture_chain
  end

  def storage_key
    key = config.storage_key
    key.respond_to?(:to_sym) ? key.to_sym : :capture_chain
  end

  def stat_count
    value = config.stat_count.to_i
    value.positive? ? value : 6
  end

  def bonus_table
    Array(config.bonus_table).map do |bonus|
      {
        min: config_value(bonus, :min).to_i,
        shiny_rate: config_value(bonus, :shiny_rate).to_i,
        perfect_ivs: config_value(bonus, :perfect_ivs).to_i
      }
    end.sort_by { |bonus| -bonus[:min] }
  end

  def break_on_player_flee?
    config.break_on_player_flee == true
  end

  def break_on_failed_battle_against_chained_species?
    config.break_on_failed_battle_against_chained_species == true
  end

  def status
    data = data_store
    {
      species: data[:species],
      count: data[:count] || 0,
      last_capture_map_id: data[:last_capture_map_id]
    }
  end

  def species
    status[:species]
  end

  def count
    status[:count]
  end

  def active?
    count.positive? && !species.nil?
  end

  def reset!
    data_store.clear
  end

  def clear_battle_context!
    data_store.delete(:current_battle_species)
    data_store.delete(:current_battle_wild)
  end

  def register_capture!(pokemon, map_id = current_map_id)
    db_symbol = pokemon_db_symbol(pokemon)
    return unless db_symbol

    data = data_store
    data[:count] = data[:species] == db_symbol ? data.fetch(:count, 0) + 1 : 1
    data[:species] = db_symbol
    data[:last_capture_map_id] = map_id
    clear_battle_context!
  end

  def apply_bonus!(pokemon)
    db_symbol = pokemon_db_symbol(pokemon)
    return pokemon unless db_symbol && chained_species?(db_symbol)
    return pokemon if pokemon_shiny?(pokemon)

    bonus = current_bonus
    return pokemon unless bonus

    force_shiny!(pokemon) if shiny_roll_success?(bonus[:shiny_rate])
    apply_perfect_ivs!(pokemon, bonus[:perfect_ivs])
    pokemon
  end

  def current_bonus
    bonus_table.find { |bonus| count >= bonus[:min] }
  end

  def shiny_rate
    current_bonus&.[](:shiny_rate)
  end

  def perfect_ivs
    current_bonus&.[](:perfect_ivs).to_i
  end

  def chained_species?(db_symbol)
    species == db_symbol && active?
  end

  def register_battle_context!(battle_info)
    data = data_store
    data[:current_battle_wild] = wild_battle?(battle_info)
    data[:current_battle_species] = extract_first_enemy_species(battle_info)
  end

  def break_from_player_flee!
    return unless break_on_player_flee?
    return unless current_battle_wild?
    return unless chained_species?(current_battle_species)

    reset!
  end

  def resolve_battle_end!(battle_info)
    begin
      register_battle_context!(battle_info) if battle_info
      return if caught_pokemon?(battle_info)
      return unless break_on_failed_battle_against_chained_species?
      return unless current_battle_wild?
      return unless chained_species?(current_battle_species)

      reset!
    ensure
      clear_battle_context!
    end
  end

  def current_map_id
    return $game_map.map_id if defined?($game_map) && $game_map

    0
  end

  def data_store
    PFM.game_state.user_data[storage_key] ||= {}
  end

  def current_battle_species
    data_store[:current_battle_species]
  end

  def current_battle_wild?
    data_store[:current_battle_wild] == true
  end

  def pokemon_db_symbol(pokemon)
    return pokemon.db_symbol if pokemon.respond_to?(:db_symbol)
    return pokemon.original.db_symbol if pokemon.respond_to?(:original) && pokemon.original.respond_to?(:db_symbol)

    nil
  end

  def pokemon_shiny?(pokemon)
    return pokemon.shiny? if pokemon.respond_to?(:shiny?)
    return pokemon.original.shiny? if pokemon.respond_to?(:original) && pokemon.original.respond_to?(:shiny?)

    false
  end

  def force_shiny!(pokemon)
    if pokemon.respond_to?(:shiny=)
      pokemon.shiny = true
    elsif pokemon.respond_to?(:original) && pokemon.original.respond_to?(:shiny=)
      pokemon.original.shiny = true
    else
      pokemon.instance_variable_set(:@shiny, true)
    end
  end

  def apply_perfect_ivs!(pokemon, desired_count)
    return if desired_count <= 0

    target = pokemon.respond_to?(:original) ? pokemon.original : pokemon
    iv_writers = %i[iv_hp= iv_atk= iv_dfe= iv_spd= iv_ats= iv_dfs=].first(stat_count)
    current_values = iv_writers.map do |writer|
      reader = writer.to_s.delete('=').to_sym
      target.respond_to?(reader) ? target.public_send(reader) : 0
    end
    missing_indexes = []
    current_values.each_with_index do |value, index|
      missing_indexes << index if value.to_i < 31
    end
    need = [desired_count - current_values.count { |value| value.to_i >= 31 }, 0].max
    missing_indexes.sample(need).each do |index|
      target.public_send(iv_writers[index], 31) if target.respond_to?(iv_writers[index])
    end
  end

  def shiny_roll_success?(rate)
    rate.to_i > 0 && rand(rate.to_i) == 0
  end

  def config_value(data, key)
    data[key] || data[key.to_s]
  end

  def wild_battle?(battle_info)
    return false unless battle_info
    return !battle_info.trainer_battle? if battle_info.respond_to?(:trainer_battle?)

    false
  end

  def caught_pokemon?(battle_info)
    battle_info && battle_info.respond_to?(:caught_pokemon) && !battle_info.caught_pokemon.nil?
  end

  def extract_first_enemy_species(battle_info)
    return nil unless battle_info

    parties = if battle_info.respond_to?(:parties)
                battle_info.parties
              elsif battle_info.instance_variable_defined?(:@parties)
                battle_info.instance_variable_get(:@parties)
              end
    enemy_party = parties&.[](1)&.first
    first_enemy = enemy_party&.first
    pokemon_db_symbol(first_enemy)
  end
end
