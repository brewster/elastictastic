require 'faraday'

module Elastictastic
  class Rotor
    NodeUnavailable = Class.new(StandardError)

    def initialize(hosts, options, &block)
      node_options = {}
      [:backoff_threshold, :backoff_start, :backoff_max].each do |key|
        node_options[key] = options.delete(key)
      end
      @connections = hosts.map do |host|
        Node.new(Faraday.new(options.merge(:url => host), &block), node_options)
      end
      @head_index = 0
    end

    Faraday::Connection::METHODS.each do |method|
      module_eval <<-RUBY, __FILE__, __LINE__+1
        def #{method}(*args)
          try_rotate { |node| node.#{method}(*args) }
        end
      RUBY
    end

    private

    def peek
      @connections[@head_index]
    end

    def shift
      peek.tap { @head_index = (@head_index + 1) % @connections.length }
    end

    def try_rotate
      last = peek
      begin
        yield shift
      rescue Faraday::Error::ConnectionFailed, NodeUnavailable => e
        raise NoServerAvailable, e.message if peek == last
        retry
      end
    end

    class Node
      def initialize(connection, options)
        @connection = connection
        @failures = 0
        @backoff_threshold = options[:backoff_threshold] || 0
        @backoff_start = options[:backoff_start]
        @backoff_max = options[:backoff_max]
      end

      Faraday::Connection::METHODS.each do |method|
        module_eval <<-RUBY, __FILE__, __LINE__+1
          def #{method}(*args)
            try_track { @connection.#{method}(*args).tap { succeeded! } }
          end
        RUBY
      end

      private

      def try_track
        raise NodeUnavailable, "Won't retry this node until #{@back_off_until}" unless available?
        begin
          yield
        rescue Faraday::Error::ConnectionFailed => e
          failed!
          raise e
        end
      end

      def available?
        !backoff_failures_reached? ||
          !backing_off?
      end

      def backing_off?
        @back_off_until &&
          @back_off_until > Time.now
      end

      def backoff_failures_reached?
        @failures >= @backoff_threshold
      end

      def succeeded!
        @failures = 0
        @back_off_until = nil
      end

      def failed!
        @failures += 1
        if @backoff_start && backoff_failures_reached?
          backoff_count = @failures - @backoff_threshold
          backoff_interval = @backoff_start * 2 ** backoff_count
          backoff_interval = @backoff_max if @backoff_max &&
            backoff_interval > @backoff_max
          @back_off_until = Time.now + backoff_interval
        end
      end
    end
  end
end
