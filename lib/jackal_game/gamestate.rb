module JackalGame

  class GameState

    def self.initial options={}
      num_of_players = options[:num_of_players] || 4
      map_size = 13

      map = Map.generate('size' => map_size)

      players = 0.upto(num_of_players - 1).map { |id| Player.new('id' => id) }

      units = []

      players.each do |player|
        location = map.spawn player.id
        units << Unit.new('location' => location, 'player_id' => player.id, 'type' => 'ship')
        3.times { units << Unit.new('location' => location, 'player_id' => player.id, 'type' => 'pirate') }
      end

      units.each_with_index { |u, i| u.id = i }

      data = {
        'map' => map,
        'players' => players,
        'units' => units
      }

      GameState.new data
    end


    def self.json_create data
      new data
    end


    attr_reader :map, :players, :units, :loot, :current_move_player_id, :current_move_unit_id, :current_move_unit_prev_location


    def initialize data={}
      @map = data['map'] || Map.new 
      @players = data['players'] || []
      @units = data['units'] || []
      @loot = data['loot'] || [] 
      @current_move_player_id = data['current_move_player_id']
      @current_move_unit_id = data['current_move_unit_id']
      @current_move_unit_prev_location = data['current_move_unit_prev_location']
    end


    def as_json options={}
      { 
        :json_class => self.class.name,
        :map => @map.as_json,
        :players => @players.as_json,
        :units => @units.as_json,
        :loot => @loot.as_json,
        :current_move_player_id => @current_move_player_id,
        :current_move_unit_id => @current_move_unit_id,
        :current_move_unit_prev_location => @current_move_unit_prev_location
      }
    end


    def start
      @current_move_player_id = 0
    end


    def move action
      return 'wrong turn' unless current_move_player_id == action.current_move_player_id

      unit = @units[action.unit]
      return 'wrong player' unless unit.player_id == current_move_player_id
      return 'wrong unit' if @current_move_unit_id.present? and @current_move_unit_id != unit.id

      location = action.location
      move_vector = @map.vector unit.location, location
      available_moves = @map.at(unit.location).available_moves(@current_move_unit_prev_location)
      return 'wrong step' unless available_moves.include? move_vector

      tile = @map.at(location)
      carried_loot = @loot[action.carried_loot] unless action.carried_loot.nil?
      return 'inaccessible tile' unless tile.accessible?(unit, carried_loot)

      unless tile.explored?
        @map.open_tile(location)
        tile = @map.at(location)
        found_loot = tile.get_loot
        if found_loot
          lid = @loot.size
          @loot.concat found_loot.map { |l| l.location = location; l.id = lid; lid += 1; l }
          action.found_loot = found_loot.map { |l| { id: l.id, location: location, type: l.type } }
        end
      end

      captured_units = @units.select{ |unit| unit.location == location && unit.player_id != current_move_player_id }
      captured_units.each do |unit|
        captured_ship = @units.select { |u| u.player_id == unit.player_id && u.type == 'ship' }.first
        unit.location = captured_ship.location
      end
      action.captured_units = captured_units.map(&:id)

      if unit.ship?
        sailors = @units.select{ |u| u.location == unit.location && u != unit }
        sailors.each { |u| u.location = location }
        action.sailors = sailors.map(&:id)
      end

      if tile.transit?
        @current_move_unit_id = unit.id
        @current_move_unit_prev_location = unit.location
        action.current_move_unit_id = unit.id

        x, y = @map.get_tile_position location
        available_moves = tile.available_moves(@map.vector(@current_move_unit_prev_location, location))
        action.available_steps = available_moves.map { |m| @map.get_tile_id(x + m.first, y + m.last)}
      else
        @current_move_unit_id = nil
        @current_move_unit_prev_location = nil
        next_player_id = (action.current_move_player_id + 1) % players.size
        action.current_move_player_id = next_player_id
        @current_move_player_id = next_player_id
      end

      action.tile = @map.at(location).value
      unit.location = location
      action.unit_location = unit.location
      carried_loot.location = location unless carried_loot.nil?

      action
    end

  end

end
