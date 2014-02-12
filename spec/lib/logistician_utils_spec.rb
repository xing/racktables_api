describe Logistician::Utils do

  describe '#delinearize_query' do

    it 'barfs when trying to overwrite a string with a hash' do
      expect{
        Logistician::Utils.delinearize_query('a'=>'a','a.b'=>'b')
      }.to raise_error(ArgumentError)
    end

  end

end
