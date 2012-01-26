module Elastictastic
  module Document
    extend ActiveSupport::Concern

    included do
      include BasicDocument
      include Callbacks
      include Observing
      include Dirty
      include MassAssignmentSecurity
      include Validations
    end
  end
end
