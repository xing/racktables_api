class Hash

  # Removes all given keys from this
  # hash and returns a new one, containing
  # all keys which were present with their
  # corresponding values.
  #
  # @example
  #   h = {:a => 1, :b => 2}
  #   k = h.delete_all(:b)
  #   k #=> {:b => 2}
  #   h #=> {:a => 1}
  def delete_all(*keys)
    nu = self.class.new
    keys.each do |key|
      if self.key?(key)
        nu[key] = self.delete(key)
      end
    end
    return nu
  end

end
