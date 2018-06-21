require 'spec_helper'

require 'util/struct'

describe Util::Struct do
  subject(:struct) { Class.new(Util::Struct) { fields :req, opt: 42 } }

  it 'allows declaring optional fields' do
    expect(struct.new(req: 44)).to have_attributes req: 44, opt: 42
    expect(struct.new(req: 44, opt: 0)).to have_attributes req: 44, opt: 0
  end
end
