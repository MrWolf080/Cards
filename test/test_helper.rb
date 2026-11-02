ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"
require_relative "test_helpers/session_test_helper"
require_relative "test_helpers/model_factory"      # <-- добавить

module ActiveSupport
  class TestCase
    parallelize(workers: :number_of_processors)

    fixtures :all

    include ModelFactory                           # <-- добавить
  end
end
