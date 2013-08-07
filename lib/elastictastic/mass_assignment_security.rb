module Elastictastic
  module MassAssignmentSecurity
    extend ActiveSupport::Concern

    if ActiveModel.version.version < '4.0'
      included do
        include ActiveModel::MassAssignmentSecurity
      end

      def attributes=(attributes)
        super(sanitize_for_mass_assignment(attributes))
      end
    else
      def attributes=(attributes)
        super(attributes.tap {|attrs| attrs.delete(:index)})
      end
    end
  end
end
