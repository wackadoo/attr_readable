# the structure of these tests and the setting up and tearing down of the
# database have been adapted from the tests in the act_as_tree plugin available
# from github via "git clone github git://github.com/amerine/acts_as_tree.git"
# Copyright (c) 2007 David Heinemeier Hansson, released under the MIT license  

require 'test/unit'

require 'rubygems'
require 'active_record'

require File.dirname(__FILE__) + '/../lib/active_record/attr_readable'
require File.dirname(__FILE__) + '/../init'

ActiveRecord::Base.establish_connection(:adapter => "sqlite3", :database => ":memory:", :verbosity => 'quiet')

# AR keeps printing annoying schema statements
$stdout = StringIO.new

def setup_db
  ActiveRecord::Base.logger
  ActiveRecord::Schema.define(:version => 1) do
    create_table :models do |t|
      t.column :name,     :string
      t.column :password, :string
    end
  end
end

def teardown_db
  ActiveRecord::Base.connection.tables.each do |table|
    ActiveRecord::Base.connection.drop_table(table)
  end
end

class Model < ActiveRecord::Base
  attr_readable :name, :password, :as => :admin 
  attr_readable :name,            :as => [ :default, :user ]
end

class AttrReadableTest < ActiveSupport::TestCase
  
  def setup
    setup_db
  end

  def teardown
    teardown_db
  end
  
  test "setting and querying readable attributes" do
    assert !Model.readable_attributes(:admin).nil?,   'readable attributes returned nil where an array was expected'
    assert !Model.readable_attributes(:admin).empty?, 'readable attributes returned an empty array'
    assert_equal 2, Model.readable_attributes(:admin).size, 'readable attributes returned an array of wrong size'
  end

  test "readable_attributes returns the correct attributes" do
    assert_equal [], Model.readable_attributes(:unknown), 'return empty list for unkown role'
    assert_equal Model.readable_attributes(:default), Model.readable_attributes, 'return attributes for :default if no role given'
    assert_equal Model.readable_attributes(:default), Model.readable_attributes(:user), 'return same attributes for :default and :user'
    assert_equal Model.readable_attributes(:default), Model.readable_attributes(:user), 'return same attributes for :default and :user'
    assert_not_equal Model.readable_attributes(:default), Model.readable_attributes(:admin), 'return different attributes for :default and :admin'
    assert_equal [ 'name' ], Model.readable_attributes(:user), 'return correct attributes for :user'
    assert_equal [ 'name', 'password' ], Model.readable_attributes(:admin), 'return correct attributes for :admin'
  end

  test "sanitization returns hash with the readable attributes" do
    instance = Model.new(:id => 1, :name => 'a name', :password => 'secret' )
    assert_equal [:name], instance.sanitized_hash(:user).keys
    assert_equal 'a name', instance.sanitized_hash(:user)[:name]
    assert_equal [:name, :password ], instance.sanitized_hash(:admin).keys
    assert_equal [ ], instance.sanitized_hash(:unkown).keys
    assert_equal instance.sanitized_hash(:admin), Model.sanitized_hash_from_model(instance, :admin)
    assert_equal instance.sanitized_hash(:admin), Model.sanitized_hash_from_hash({ :name => 'a name', :password => 'secret', :id => 1}, :admin)
  end

  test "sanitization strips all non-readable attributes from hash" do
    instance = Model.new(:id => 1, :name => 'a name', :password => 'secret' )
    assert !instance.sanitized_hash(:admin).keys.include?(:id)
    assert !instance.sanitized_hash(:user).keys.include?(:password)
    assert !instance.sanitized_hash(:default).keys.include?(:password)
    assert !instance.sanitized_hash(:unknown).keys.include?(:name)
  end
    
end
