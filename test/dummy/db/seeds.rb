def create_view(visit, controller:, action:, verb:, path:, verified:, time:, version: nil)
  Skadi::View.create(
    visit: visit,
    view_token: Random.uuid_v7,
    verified: verified,
    controller: controller,
    action: action,
    verb: verb,
    path: path,
    query_params: {},
    version: version,

    created_at: time,
    updated_at: time,
  )
end

def create_event(visit, view, name:, time:, properties: {})
  Skadi::Event.create(
    visit: visit,
    view: view,
    name: name,
    properties: properties,
    created_at: time + Random.rand(4..28).seconds,
  )
end

Skadi::Visit.destroy_all
Skadi::View.destroy_all
Skadi::Event.destroy_all
Skadi::Demographic.destroy_all

start_time = Time.current.yesterday

puts "Seeding Skadi database (#{Rails.env}):"
10_000.times do |i|
  print "." if i % 100 == 0
  # Let's not start with all of our mod tests matching by multiplying and adding a prime to each i
  i = (i * 31_313) + 13_331

  start_time -= Random.rand(1..30).minutes
  offset = 0

  verified = i % 23 != 0

  visit = unless i % 13 == 0
    Skadi::Visit.create(
      visit_token: Random.uuid_v7,
      # Occasionally we'll have a visit with DNT
      tracking_token: (i % 102 == 0) ? nil : Random.uuid_v7,
      user_id: nil,

      referrer: (i % 31 == 0) ? "example.com/path" : nil,
      landing_page: (i % 19 == 0) ? "/" : "/cart",

      utm_source: (i % 17 == 0) ? "test_source" : nil,
      utm_medium: (i % 17 == 0) ? "test_medium" : nil,
      utm_term: (i % 17 == 0) ? "test_term" : nil,
      utm_content: (i % 17 == 0) ? "test_content" : nil,
      utm_campaign: (i % 17 == 0) ? "test_campaign" : nil,

      # Most visits should be verified
      verified: verified,

      created_at: start_time,
      updated_at: start_time,
    )
  end

  view = nil

  unless i % 19 == 0
    view = create_view(visit, controller: "home", action: "show", verb: "GET", path: "/", verified:, time: start_time, version: (i % 57) ? "A" : "B")

    create_event(visit, view, name: "clicked banner", time: start_time) if i % 23 > 19
  end

  next if i % 37 < 24

  offset += Random.rand(30..659).seconds
  view = create_view(visit, controller: "cart", action: "show", verb: "GET", path: "/cart", verified:, time: start_time + offset)

  create_event(visit, view, name: "clicked upsell", time: start_time + offset) if i % 29 > 26

  # Let's not make all the paths the same
  if i % 11 == 1
    offset += Random.rand(30..659).seconds
    create_view(visit, controller: "home", action: "show", verb: "GET", path: "/", verified:, time: start_time)
  end
  if i % 13 == 1
    offset += Random.rand(30..659).seconds
    create_view(visit, controller: "cart", action: "show", verb: "GET", path: "/cart", verified:, time: start_time + offset)
  end

  next if i % 37 < 31

  offset += Random.rand(30..659).seconds
  create_view(visit, controller: "checkout", action: "create", verb: "POST", path: "/checkout", verified:, time: start_time + offset)

  next if i % 101 == 0

  offset += Random.rand(3).seconds
  view = create_view(visit, controller: "checkout", action: "thank_you", verb: "GET", path: "/thank-you", verified:, time: start_time + offset)

  create_event(visit, view, name: "review", properties: { starts: Random.rand(1..5) }, time: start_time + offset) if i % 31 > 27
end

print "\n"
