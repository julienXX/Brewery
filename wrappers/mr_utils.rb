module MrUtils
  module_function

  def string_from_data(data)
    NSString.alloc.initWithData(data, encoding:NSUTF8StringEncoding)
  end
end