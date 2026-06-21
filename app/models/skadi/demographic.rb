module Skadi
  class Demographic < ApplicationRecord
    self.implicit_order_column = :recorded_on

    validates :name, presence: true
    validates :value, presence: true

    validates :recorded_on, presence: true

    def self.upsert(*demographics)
      demographics_to_update = demographics.map do |demographic|
        {
          name: demographic[:name].strip[0, 255],
          value: demographic[:value].strip[0, 255],
          # SQL specifies NULL values are not equal, so we need to default the URI to an empty string
          # to ensure the unique index works correctly
          uri: demographic[:uri]&.strip&.[](0, 255) || "",
          recorded_on: Time.current,
          count: 1,
        }
      end

      Skadi::Demographic.upsert_all(
        demographics_to_update,
        unique_by: [:uri, :name, :value, :recorded_on],
        on_duplicate: Arel.sql("count = skadi_demographics.count + 1"),
        returning: false,
      )
    end
  end
end
