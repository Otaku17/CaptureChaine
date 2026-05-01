class Interpreter
  def capture_chain_status
    CaptureChain.status
  end

  def capture_chain_count
    CaptureChain.count
  end

  def capture_chain_species
    CaptureChain.species
  end

  def capture_chain_bonus
    CaptureChain.current_bonus
  end

  def capture_chain_shiny_rate
    CaptureChain.shiny_rate
  end

  def reset_capture_chain
    CaptureChain.reset!
  end
end
