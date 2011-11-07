module Elastictastic
  module NestedDocument
    extend ActiveSupport::Concern

    included do
      include Properties
      include Dirty
      include MassAssignmentSecurity
    end
  end
end
