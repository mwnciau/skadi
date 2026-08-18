module Skadi
  module Helpers
    class Sql
      class << self
        # Provides the keyword for case insensitive LIKE
        def operator(model, operator)
          return case operator
            when "like"
              ilike(model)
            when "not like"
              "NOT #{ilike(model)}"
            else
              operator
          end
        end

        # Provides the keyword for case insensitive LIKE
        def ilike(model)
          case model.connection.adapter_name
            when "PostgreSQL"
            "ILIKE"
            when "Mysql2", "SQLite"
            "LIKE"
            else
            raise ::Skadi::Dashboard::UnsupportedDatabaseError.new("The database adapter #{model.connection.adapter_name} is not supported")
          end
        end

        def string_before_separator(model, field, separator)
          case model.connection.adapter_name
            when "PostgreSQL"
            "SPLIT_PART(#{model.table_name}.#{field}, '#{separator}', 1)"
            when "Mysql2"
            "SUBSTRING_INDEX(#{model.table_name}.#{field}, '#{separator}', 1)"
            when "SQLite"
            "SUBSTR(#{model.table_name}.#{field}, 1, INSTR(#{model.table_name}.#{field}, '#{separator}') - 1)"
            else
            raise ::Skadi::Dashboard::UnsupportedDatabaseError.new("The database adapter #{model.connection.adapter_name} is not supported")
          end
        end

        def time_series(time_series, model, date_field)
          case time_series
            when "daily"
            day_of_date(model, date_field)
            when "weekly"
            week_of_date(model, date_field)
            when "monthly"
            month_of_date(model, date_field)
            else
            raise ::Skadi::Dashboard::DatasetConfigurationError.new("The time_series #{time_series} is invalid")
          end
        end

        def day_of_date(_model, date_field)
          "DATE(#{date_field})"
        end

        def week_of_date(model, date_field)
          case model.connection.adapter_name
            when "PostgreSQL"
            "DATE_TRUNC('week', #{date_field})::date"
            when "Mysql2"
            "DATE_SUB(DATE(#{date_field}), INTERVAL WEEKDAY(#{date_field}) DAY)"
            when "SQLite"
            "DATE(#{date_field}, '-' || ((CAST(STRFTIME('%w', #{date_field}) AS INTEGER) + 6) % 7) || ' days')"
            else
            raise ::Skadi::Dashboard::UnsupportedDatabaseError.new("The database adapter #{model.connection.adapter_name} is not supported")
          end
        end

        def month_of_date(model, date_field)
          case model.connection.adapter_name
            when "PostgreSQL"
            "DATE_TRUNC('month', #{date_field})::date"
            when "Mysql2"
            "DATE_FORMAT(#{date_field}, '%Y-%m-01')"
            when "SQLite"
            "DATE(#{date_field}, 'start of month')"
            else
            raise ::Skadi::Dashboard::UnsupportedDatabaseError.new("The database adapter #{model.connection.adapter_name} is not supported")
          end
        end
      end
    end
  end
end
