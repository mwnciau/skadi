Skadi.configure do |config|
  config.user_model = "DummyUser"
  config.user_method = :current_user

  config.use_anonymity_sets = true
end
