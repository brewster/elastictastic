require 'faraday'

module Elastictastic
  class Rotor

    def initialize(hosts, options, &block)
      @connections = hosts.map do |host|
        Faraday.new(options.merge(:url => host), &block)
      end
      @head_index = 0
    end

    def peek
      @connections[@head_index]
    end

    def shift
      peek.tap { @head_index = (@head_index + 1) % @connections.length }
    end

    Faraday::Connection::METHODS.each do |method|
      module_eval <<-RUBY, __FILE__, __LINE__+1
        def #{method}(*args)
          last = peek
          begin
            shift.#{method}(*args)
          rescue Faraday::Error::ConnectionFailed => e
            raise NoServerAvailable, e.message if peek == last
            retry
          end
        end
      RUBY
    end
  end
end
