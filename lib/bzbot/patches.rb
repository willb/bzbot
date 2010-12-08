# patches.rb:  monkeypatches required by isaac

class String
  def start_with?(str)
    !!(self =~ /^#{str}/)
  end
end
