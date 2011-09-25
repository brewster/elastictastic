module Elastictastic
  CancelBulkOperation = Class.new(StandardError)
  IllegalModificationError = Class.new(StandardError)
  OperationNotAllowed = Class.new(StandardError)
  NoServerAvailable = Class.new(StandardError)
end
