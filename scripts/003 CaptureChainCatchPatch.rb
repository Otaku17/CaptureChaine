module Battle
  class Logic
    class CatchHandler
      alias __capture_chain_try_to_catch_pokemon try_to_catch_pokemon

      def try_to_catch_pokemon(target, pkm_ally, ball)
        caught = __capture_chain_try_to_catch_pokemon(target, pkm_ally, ball)
        CaptureChain.register_capture!(target) if caught
        caught
      end
    end
  end
end
