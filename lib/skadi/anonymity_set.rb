module Skadi
  class AnonymitySet
    # Generates a unique token for the given IP and user agent
    # @return [String]
    def self.calculate(ip, user_agent)
      return nil unless Skadi.configuration.use_anonymisation_sets

      user_fingerprint = "#{ip}|#{user_agent}"

      hash = OpenSSL::HMAC.hexdigest("sha256", anonymity_set_pepper, user_fingerprint)

      # We want a UUID-like string to be compatible with the uuid type if the database is PostgreSQL, but don't need a valid UUID
      "#{hash[0, 8]}-#{hash[8, 4]}-#{hash[12, 4]}-#{hash[16, 4]}-#{hash[20, 12]}"
    end

    # Generate a pepper to be used in the anonymity set hash
    # @return [String]
    def self.anonymity_set_pepper
      duration = Skadi.configuration.anonymisation_set_duration
      reset_hour = Skadi.configuration.anonymisation_set_reset_hour

      pepper_expiry = Time.current + duration

      if reset_hour
        # We always want to truncate the duration to the reset hour, so if the expiry hour is before the reset hour, go back to the previous day
        pepper_expiry -= 1.day if pepper_expiry.hour < reset_hour
        
        pepper_expiry = pepper_expiry.change(hour: reset_hour, min: 0, sec: 0)

        # Handle the case where the duration is less than one day, so the expiry is in the past
        pepper_expiry += 1.day if pepper_expiry < Time.current
      end

      Rails.cache.fetch("skadi/anonymity_set_pepper", expires_in: pepper_expiry.to_i - Time.current.to_i) do
        SecureRandom.hex(32)
      end
    end
  end
end