module Model

  class VLan < Sequel::Model(DB[:VLANDescription])

    def self.capture(union)
      union.row_proc = self
      @dataset_method_modules.each{|m| union.extend(m)} if @dataset_method_modules
      @dataset_methods.each{|meth, block| union.meta_def(meth, &block)} if @dataset_methods
      union.model = self if union.respond_to?(:model=)
      return union
    end

    class Domain < Sequel::Model(DB[:VLANDomain])

      one_to_many :vlans, class: 'Model::VLan'

      alias to_s description

    end

    many_to_one :domain, class: 'Model::VLan::Domain'

    many_to_many :ipv4networks, class: 'Model::Network::IPv4', join_table: 'VLANIPv4', left_key: [:domain_id,:vlan_id], right_key: :ipv4net_id
    many_to_many :ipv6networks, class: 'Model::Network::IPv6', join_table: 'VLANIPv6', left_key: [:domain_id,:vlan_id], right_key: :ipv6net_id

    many_to_many :networks, class: 'Model::Network',
      select: Sequel::SQL::ColumnAll.new(:networks),
      left_key: [:domain_id,:vlan_id],
      dataset: proc{
        Model::Network.capture(
          ipv4networks_dataset.select(:id,:ip,:mask,:name,:comment,Sequel.expr(4).as(:version)).union(
          ipv6networks_dataset.select(:id,:ip,:mask,:name,:comment,Sequel.expr(6).as(:version)),
            :alias => :networks
          )
        )
      },
      eager_loader: proc{|eo|
        id_map = eo[:id_map]
        ds = DB[:IPv4Network].select(:id,:ip,:mask,:name,:comment,Sequel.expr(4).as(:version))
          .inner_join(:VLANIPv4, :ipv4net_id => :id).select_more(:domain_id,:vlan_id)
          .union(
            DB[:IPv6Network].select(:id,:ip,:mask,:name,:comment,Sequel.expr(6).as(:version))
              .inner_join(:VLANIPv6, :ipv6net_id => :id).select_more(:domain_id,:vlan_id),
            :alias => :networks
          ).where([:domain_id,:vlan_id] => id_map.keys)
        eo[:rows].each do |vlan|
          vlan.associations[:networks] = []
        end
        ds.each do |row|
          nw = Model::Network.call(row)
          nw.associations[:vlan] = nil
          id_map[[row[:domain_id],row[:vlan_id]]].each do |vlan|
            nw.associations[:vlan] = vlan
            vlan.associations[:networks] << nw
          end
        end
      }

  end

end
