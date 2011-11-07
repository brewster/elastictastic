class PostObserver < Elastictastic::Observer
  %w(create update save destroy).each do |lifecycle|
    %w(before after).each do |phase|
      module_eval <<-RUBY, __FILE__, __LINE__ + 1
        def #{phase}_#{lifecycle}(post)
          post.observers_that_ran << :#{phase}_#{lifecycle}
        end
      RUBY
    end
  end
end
