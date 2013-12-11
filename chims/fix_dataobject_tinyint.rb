# DataObjects insists on converting TinyInt to boolean regardless of the size.
# Therefore: disable this feature entirely!
if defined? DataObjects
  DataObjects::Mysql::Command.class_eval do

    alias_method :execute_reader2, :execute_reader

    def execute_reader
      reader = execute_reader2
      reader.instance_variable_get(:@field_types).map!{|t| t == TrueClass ? Integer : t }
      if block_given?
        yield reader
        reader.close
      end
      return reader
    end

  end
end