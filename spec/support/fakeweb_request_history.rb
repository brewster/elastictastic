class <<FakeWeb
  def last_request=(request)
    requests << request
  end

  def last_request
    requests.last
  end

  def requests
    @requests ||= []
  end
end
