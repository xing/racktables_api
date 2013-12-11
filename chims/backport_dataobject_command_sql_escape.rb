if defined? DataObjects
  class DataObjects::Command

    alias_method :old_escape_sql, :escape_sql

    def escape_sql(args)
      return @text if args.empty?
      return old_escape_sql(args)
    end

  end
end