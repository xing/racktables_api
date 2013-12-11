require 'set'
module Model

  class Tag < Sequel::Model(DB[:TagTree])

    class Assignment < Sequel::Model(DB[:TagStorage])

      many_to_one :tag, :class => Tag

    end

    many_to_one :parent, :class=>self
    one_to_many :children, :key=>:parent_id, :class => self
    one_to_many :assignments, :key=>:tag_id, :class => Assignment

    one_to_many :ancestors, :eager_loader => (proc{|eo|
      id_map = { nil => nil }
      match_queue = []
      fetch_queue = []
      eo[:rows].each do |tag| 
        id_map[tag.id] = tag
        match_queue << tag
      end
      loop do
        missing = Hash.new{|hsh, key| hsh[key] = [] }
        match_queue.each do |tag|
          if id_map.key? tag.parent_id
            tag.associations[:parent]=id_map[tag.parent_id]
          else
            missing[tag.parent_id] << tag
          end
        end
        break if missing.empty?
        Tag.filter(:id=>missing.keys).each do |tag|
          id_map[tag.id] = tag
        end
        missing.keys.each do |pid|
          id_map[pid] ||= nil
        end
        match_queue = missing.values.flatten(1)
      end
    }), :class => Tag

    module HierachyFetcher

      def descendants(options={})
        result = {}
        if options[:with_self]
          missing = []
          self.each do |tag|
            result[tag.id] = tag
            missing << tag.id
          end
        else
          missing = self.map(:id)
        end
        until missing.empty?
          next_missing = []
          Tag.filter(:parent_id => missing).each do |tag|
            next_missing << tag.pk
            tag.parent = result[tag[:parent_id]]
            result[tag.id] = tag
          end
          missing = next_missing
        end
        return result.values
      end

      def ancestors(options={})
        if options[:with_self]
          result = self.all
          missing = result.map(&:parent_id)
        else
          result = []
          missing = self.map(:parent_id)
        end
        begin
          next_missing = []
          Tag.filter(:id => missing).each do |tag|
            next if result.include? tag
            next_missing << tag.parent_id
            result << tag
          end
          missing = next_missing
        end until missing.empty?
        return result
      end
    end

    module PathQuery

      def where_path(*path, lst)
        q = path.inject(nil){|memo, name|
          Model::Tag.select(:id).where( :tag => name, :parent_id => memo )
        }
        return where( :tag => lst, :parent_id => q )
      end

    end

    dataset_extend HierachyFetcher
    dataset_extend PathQuery

    def descendants
      result = []
      missing = [self.pk]
      begin
        next_missing = []
        Tag.filter(:parent_id => missing).each do |tag|
          next_missing << tag.pk
          result << tag
        end
        missing = next_missing
      end until missing.empty?
      result
    end

    def ancestors
      result = []
      current = self.parent
      while current
        result << current
        current = current.parent
      end
      return result
    end

  end

end
