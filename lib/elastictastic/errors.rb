module Elastictastic
  Error = Class.new(StandardError)
  CancelSave = Class.new(Error)
  IllegalModificationError = Class.new(Error)
  OperationNotAllowed = Class.new(Error)
  MissingParameter = Class.new(Error)
  NoServerAvailable = Class.new(Error)
  RecordInvalid = Class.new(Error)
end
