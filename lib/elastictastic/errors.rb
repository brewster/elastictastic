module Elastictastic
  CancelSave = Class.new(StandardError)
  IllegalModificationError = Class.new(StandardError)
  OperationNotAllowed = Class.new(StandardError)
  NoServerAvailable = Class.new(StandardError)
  RecordInvalid = Class.new(StandardError)
end
