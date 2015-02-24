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


    attr_reader :map, :players, :units, :current_move_player_id


    def initialize data={}
      @map = data['map'] || Map.new 
      @players = data['players'] || []
      @units = data['units'] || []
      @current_move_player_id = data['current_move_player_id']
    end


    def as_json options={}
      { 
        :json_class => self.class.name,
        :map => @map.as_json,
        :players => @players.as_json,
        :units => @units.as_json,
        :current_move_player_id => @current_move_player_id
      }
    end


    def start
      @current_move_player_id = 0
    end


    def move action
      return 'wrong turn' unless current_move_player_id == action.current_move_player_id

      unit = @units[action.unit]
      return 'wrong unit' unless unit.player_id == current_move_player_id
      return 'wrong step' unless @map.locations_close(unit.location, action.location)

      location = action.location
      tile = @map.at(location)
      return 'inaccessible tile' unless tile.accessible?

      unless tile.explored?
        @map.open_tile(location)
        tile = @map.at(location)
      end

      captured_units = @units.select{ |unit| unit.location == location && unit.player_id != current_move_player_id }
      captured_units.each { |unit| unit.location = @map.spawn(unit.player_id) }
      action.captured_units = captured_units.map(&:id)

      action.tile = @map.at(location).type
      unit.location = location if tile.accessible?
      action.unit_location = unit.location

      next_player_id = (action.current_move_player_id + 1) % players.size
      action.current_move_player_id = next_player_id
      @current_move_player_id = next_player_id
      action
    end

  end

end
