module Model
  class DictionaryValue < Sequel::Model(DB[:Dictionary])

    # See for mapping:
    # http://sourceforge.net/apps/mediawiki/racktables/index.php?title=RackTablesDevelGuide#meaning_of_chapter_ID
    MODEL_MAP = {1=>'Model::ObjectType'}

    one_to_many :attributes, :class=>'Model::Attribute', :key => :uint_value, :foreign_key => :dict_key

    plugin :single_table_inheritance, :chapter_id,
      :model_map=>MODEL_MAP, :key_map=>proc{|model| x = MODEL_MAP.rassoc(model.to_s); x.nil? ? nil : x[0] }

  end
end
require 'model/object_type'
require 'model/attribute'
