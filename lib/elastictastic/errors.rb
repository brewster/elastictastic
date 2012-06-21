module Elastictastic
  Error = Class.new(StandardError)
  CancelSave = Class.new(Error)
  IllegalModificationError = Class.new(Error)
  OperationNotAllowed = Class.new(Error)
  MissingParameter = Class.new(Error)

  class ConnectionFailed < Error
    attr_reader :source

    def initialize(source)
      super(source.message)
      @source = source
    end
  end

  NoServerAvailable = Class.new(ConnectionFailed)
  RecordInvalid = Class.new(Error)
end
