module Model

  class User

    class Account < Sequel::Model(:UserAccount)
    end

    def self.account_or_hash_attr(name)
      self.class_eval(<<RUBY)
def #{name}
  @account ? @account.send(#{name.inspect}) : @data[#{name.inspect}]
end
RUBY
    end

    def initialize(account_or_hash)
      if account_or_hash.kind_of? Account
        @account = account_or_hash
      else
        @data = account_or_hash
      end
    end

  end

end
