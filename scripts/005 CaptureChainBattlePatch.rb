module Battle
  class Scene
    alias __capture_chain_initialize initialize

    def initialize(battle_info)
      CaptureChain.register_battle_context!(battle_info)
      __capture_chain_initialize(battle_info)
    end
  end

  class Logic
    class FleeHandler
      alias __capture_chain_attempt attempt

      def attempt(*args)
        result = __capture_chain_attempt(*args)
        CaptureChain.break_from_player_flee! if result == true || result == :success
        result
      end
    end

    class BattleEndHandler
      alias __capture_chain_process process

      def process(*args)
        result = __capture_chain_process(*args)
        battle_info = logic.respond_to?(:battle_info) ? logic.battle_info : nil
        CaptureChain.resolve_battle_end!(battle_info)
        result
      end
    end
  end
end
